package foundation

import (
	"context"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

const defaultAuthorizationPolicyTimeout = 3 * time.Second

// PolicyBindingReasonCode is the exact stable result returned by the accepted
// decision.bind_authorization_policy(uuid) Foundation routine.
type PolicyBindingReasonCode string

const (
	AuthorizationPolicySelected        PolicyBindingReasonCode = "AUTHORIZATION_POLICY_SELECTED"
	AuthorizationPolicyNotFound        PolicyBindingReasonCode = "AUTHORIZATION_POLICY_NOT_FOUND"
	AuthorizationPolicyAmbiguous       PolicyBindingReasonCode = "AUTHORIZATION_POLICY_AMBIGUOUS"
	AuthorizationPolicyContextMismatch PolicyBindingReasonCode = "AUTHORIZATION_POLICY_CONTEXT_MISMATCH"
	AuthorizationDecisionFinalized     PolicyBindingReasonCode = "AUTHORIZATION_DECISION_ALREADY_FINALIZED"
	AuthorizationPolicyAlreadyBound    PolicyBindingReasonCode = "AUTHORIZATION_POLICY_ALREADY_BOUND"
)

// DecisionID is one canonical non-zero UUID identifying an existing Decision
// Record. The type prevents callers from passing unvalidated free-form text to
// the controlled database adapter.
type DecisionID [16]byte

// String returns the canonical lowercase UUID representation.
func (id DecisionID) String() string {
	encoded := make([]byte, 36)
	hex.Encode(encoded[0:8], id[0:4])
	encoded[8] = '-'
	hex.Encode(encoded[9:13], id[4:6])
	encoded[13] = '-'
	hex.Encode(encoded[14:18], id[6:8])
	encoded[18] = '-'
	hex.Encode(encoded[19:23], id[8:10])
	encoded[23] = '-'
	hex.Encode(encoded[24:36], id[10:16])
	return string(encoded)
}

// ParseDecisionID validates and normalizes one canonical UUID. The all-zero
// UUID is rejected because it cannot be a valid governed Decision Record
// reference.
func ParseDecisionID(value string) (DecisionID, error) {
	trimmed := strings.TrimSpace(value)
	if len(trimmed) != 36 ||
		trimmed[8] != '-' ||
		trimmed[13] != '-' ||
		trimmed[18] != '-' ||
		trimmed[23] != '-' {
		return DecisionID{}, &Error{
			Kind:      ErrorValidation,
			Operation: "parse decision reference",
			Cause:     errors.New("decision reference is not a canonical UUID"),
		}
	}

	compact := strings.ReplaceAll(trimmed, "-", "")
	decoded, err := hex.DecodeString(compact)
	if err != nil || len(decoded) != 16 {
		return DecisionID{}, &Error{
			Kind:      ErrorValidation,
			Operation: "parse decision reference",
			Cause:     errors.New("decision reference contains invalid UUID text"),
		}
	}

	var id DecisionID
	copy(id[:], decoded)
	if id == (DecisionID{}) {
		return DecisionID{}, &Error{
			Kind:      ErrorValidation,
			Operation: "parse decision reference",
			Cause:     errors.New("decision reference must not be the zero UUID"),
		}
	}
	return id, nil
}

// PolicyBindingResult preserves the exact Decision Record reference and stable
// reason code returned by PostgreSQL. It does not infer or accept a caller-
// supplied policy, decision result, or reason.
type PolicyBindingResult struct {
	DecisionID DecisionID
	ReasonCode PolicyBindingReasonCode
}

// ErrorKind classifies adapter failures without disclosing database messages,
// identifiers, credentials, or caller-supplied values.
type ErrorKind string

const (
	ErrorValidation       ErrorKind = "validation"
	ErrorIdentity         ErrorKind = "identity"
	ErrorDatabaseContract ErrorKind = "database_contract"
	ErrorOperation        ErrorKind = "operation"
)

// Error is safe to return to structured logging through SafeMessage.
type Error struct {
	Kind      ErrorKind
	Operation string
	Cause     error
}

func (e *Error) Error() string {
	operation := strings.TrimSpace(e.Operation)
	if operation == "" {
		operation = "controlled operation"
	}
	kind := e.Kind
	if kind == "" {
		kind = ErrorOperation
	}
	return fmt.Sprintf("foundation %s failed: %s", operation, kind)
}

func (e *Error) Unwrap() error       { return e.Cause }
func (e *Error) SafeMessage() string { return e.Error() }

// Diagnostic returns one bounded classification suitable for logs and metrics.
func Diagnostic(err error) string {
	if err == nil {
		return "foundation_no_error"
	}
	if errors.Is(err, context.Canceled) {
		return "foundation_context_canceled"
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "foundation_deadline_exceeded"
	}

	databaseDiagnostic := database.Diagnostic(err)
	if databaseDiagnostic != "database_operation_failed" {
		return databaseDiagnostic
	}

	var adapterError *Error
	if errors.As(err, &adapterError) && adapterError.Kind != "" {
		return "foundation_" + string(adapterError.Kind)
	}
	return "foundation_operation_failed"
}

type authorizationPolicyBinder interface {
	BindAuthorizationPolicy(context.Context, string) (string, error)
}

// AuthorizationPolicyAdapter exposes exactly one accepted protected Foundation
// operation. It has no transport, authentication, generic query, retry, or
// direct table-access authority.
type AuthorizationPolicyAdapter struct {
	binder  authorizationPolicyBinder
	timeout time.Duration
}

// NewAuthorizationPolicyAdapter binds the adapter to the exact Foundation API
// database identity. Other process identities are rejected before SQL runs.
func NewAuthorizationPolicyAdapter(pool *database.Pool) (*AuthorizationPolicyAdapter, error) {
	if pool == nil {
		return nil, &Error{
			Kind:      ErrorIdentity,
			Operation: "construct authorization policy adapter",
			Cause:     errors.New("database pool is required"),
		}
	}
	return newAuthorizationPolicyAdapter(
		pool,
		pool.Identity(),
		defaultAuthorizationPolicyTimeout,
	)
}

func newAuthorizationPolicyAdapter(
	binder authorizationPolicyBinder,
	identity database.ServiceIdentity,
	timeout time.Duration,
) (*AuthorizationPolicyAdapter, error) {
	if binder == nil {
		return nil, &Error{
			Kind:      ErrorIdentity,
			Operation: "construct authorization policy adapter",
			Cause:     errors.New("authorization policy binding boundary is required"),
		}
	}
	if identity != database.FoundationAPI {
		return nil, &Error{
			Kind:      ErrorIdentity,
			Operation: "construct authorization policy adapter",
			Cause:     errors.New("database identity is not authorized for this adapter"),
		}
	}
	if timeout <= 0 || timeout > 5*time.Second {
		return nil, &Error{
			Kind:      ErrorValidation,
			Operation: "construct authorization policy adapter",
			Cause:     errors.New("operation timeout is outside the accepted boundary"),
		}
	}

	return &AuthorizationPolicyAdapter{
		binder:  binder,
		timeout: timeout,
	}, nil
}

// BindAuthorizationPolicy invokes exactly
// decision.bind_authorization_policy(uuid). PostgreSQL owns row locking,
// policy resolution, terminal deny persistence, and statement atomicity.
func (adapter *AuthorizationPolicyAdapter) BindAuthorizationPolicy(
	ctx context.Context,
	decisionID DecisionID,
) (PolicyBindingResult, error) {
	result := PolicyBindingResult{DecisionID: decisionID}
	if adapter == nil || adapter.binder == nil {
		return result, &Error{
			Kind:      ErrorIdentity,
			Operation: "bind authorization policy",
			Cause:     errors.New("adapter is unavailable"),
		}
	}
	if ctx == nil {
		return result, &Error{
			Kind:      ErrorValidation,
			Operation: "bind authorization policy",
			Cause:     errors.New("context is required"),
		}
	}
	if decisionID == (DecisionID{}) {
		return result, &Error{
			Kind:      ErrorValidation,
			Operation: "bind authorization policy",
			Cause:     errors.New("decision reference is required"),
		}
	}

	operationContext, cancel := context.WithTimeout(ctx, adapter.timeout)
	defer cancel()

	reasonText, err := adapter.binder.BindAuthorizationPolicy(
		operationContext,
		decisionID.String(),
	)
	if err != nil {
		return result, &Error{
			Kind:      ErrorOperation,
			Operation: "bind authorization policy",
			Cause:     err,
		}
	}

	reasonCode, err := parsePolicyBindingReasonCode(reasonText)
	if err != nil {
		return result, err
	}
	result.ReasonCode = reasonCode
	return result, nil
}

func parsePolicyBindingReasonCode(value string) (PolicyBindingReasonCode, error) {
	reasonCode := PolicyBindingReasonCode(value)
	switch reasonCode {
	case AuthorizationPolicySelected,
		AuthorizationPolicyNotFound,
		AuthorizationPolicyAmbiguous,
		AuthorizationPolicyContextMismatch,
		AuthorizationDecisionFinalized,
		AuthorizationPolicyAlreadyBound:
		return reasonCode, nil
	default:
		return "", &Error{
			Kind:      ErrorDatabaseContract,
			Operation: "bind authorization policy",
			Cause:     errors.New("database returned an unrecognized reason code"),
		}
	}
}
