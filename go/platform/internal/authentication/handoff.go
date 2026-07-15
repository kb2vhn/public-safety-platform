// Package authentication verifies bounded trusted-gateway authentication
// handoffs. A verified handoff establishes authentication context only; it does
// not authorize a protected Foundation operation.
package authentication

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"
)

const (
	MinimumKeyBytes      = 32
	MaximumKeyBytes      = 64
	MaximumReplayEntries = 1024
	MaximumHandoffAge    = 30 * time.Second
	MaximumFutureSkew    = 5 * time.Second
)

// ErrorKind classifies a handoff failure without disclosing signed values.
type ErrorKind string

const (
	ErrorMalformed ErrorKind = "malformed"
	ErrorInvalid   ErrorKind = "invalid"
	ErrorStale     ErrorKind = "stale"
	ErrorReplay    ErrorKind = "replay"
	ErrorCapacity  ErrorKind = "capacity"
)

// Error is safe for bounded diagnostics. Cause is retained for tests only.
type Error struct {
	Kind  ErrorKind
	Cause error
}

func (e *Error) Error() string {
	kind := e.Kind
	if kind == "" {
		kind = ErrorInvalid
	}
	return fmt.Sprintf("authentication handoff rejected: %s", kind)
}
func (e *Error) Unwrap() error       { return e.Cause }
func (e *Error) SafeMessage() string { return e.Error() }

// Diagnostic returns one bounded, non-secret classification.
func Diagnostic(err error) string {
	var handoffError *Error
	if errors.As(err, &handoffError) && handoffError.Kind != "" {
		return "authentication_handoff_" + string(handoffError.Kind)
	}
	return "authentication_handoff_rejected"
}

// ID is a canonical non-zero UUID used for request correlation only.
type ID [16]byte

// String returns the canonical lowercase UUID representation.
func (id ID) String() string {
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

// ParseID validates one canonical non-zero UUID.
func ParseID(value string) (ID, error) {
	trimmed := strings.TrimSpace(value)
	if len(trimmed) != 36 ||
		trimmed[8] != '-' ||
		trimmed[13] != '-' ||
		trimmed[18] != '-' ||
		trimmed[23] != '-' {
		return ID{}, &Error{Kind: ErrorMalformed, Cause: errors.New("identifier layout is invalid")}
	}
	decoded, err := hex.DecodeString(strings.ReplaceAll(trimmed, "-", ""))
	if err != nil || len(decoded) != 16 {
		return ID{}, &Error{Kind: ErrorMalformed, Cause: errors.New("identifier text is invalid")}
	}
	var id ID
	copy(id[:], decoded)
	if id == (ID{}) {
		return ID{}, &Error{Kind: ErrorMalformed, Cause: errors.New("identifier must not be zero")}
	}
	return id, nil
}

// Input is the exact signed transport handoff supplied by the trusted local
// authentication gateway. BodyDigest is SHA-256 over the received request body.
type Input struct {
	Method          string
	Path            string
	BodyDigest      [sha256.Size]byte
	RequestID       string
	CorrelationID   string
	Subject         string
	Provider        string
	AssertionID     string
	AuthenticatedAt string
	Nonce           string
	Signature       string
}

// Context is the trusted authentication result after signature, freshness, and
// replay verification. These values remain authentication context and are not
// authorization inputs to the Step 5 database adapter.
type Context struct {
	RequestID       ID
	CorrelationID   ID
	Subject         string
	Provider        string
	AssertionID     string
	AuthenticatedAt time.Time
	ReceivedAt      time.Time
}

// Clock permits deterministic freshness and replay tests.
type Clock func() time.Time

// Verifier owns a copied HMAC key and a bounded in-memory replay window.
type Verifier struct {
	key     []byte
	now     Clock
	mu      sync.Mutex
	replays map[[sha256.Size]byte]time.Time
}

// NewVerifier validates and copies one service-specific HMAC key.
func NewVerifier(key []byte, now Clock) (*Verifier, error) {
	if len(key) < MinimumKeyBytes || len(key) > MaximumKeyBytes {
		return nil, &Error{Kind: ErrorMalformed, Cause: errors.New("key length is outside the accepted boundary")}
	}
	if now == nil {
		now = time.Now
	}
	keyCopy := append([]byte(nil), key...)
	return &Verifier{
		key:     keyCopy,
		now:     now,
		replays: make(map[[sha256.Size]byte]time.Time),
	}, nil
}

// Verify authenticates one exact handoff and records its replay key atomically.
func (v *Verifier) Verify(input Input) (Context, error) {
	if v == nil || len(v.key) == 0 {
		return Context{}, &Error{Kind: ErrorInvalid, Cause: errors.New("verifier is unavailable")}
	}
	if input.Method != "POST" || input.Path != "/v1/foundation/authorization-policy-bindings" {
		return Context{}, &Error{Kind: ErrorMalformed, Cause: errors.New("signed method or path is invalid")}
	}

	requestID, err := ParseID(input.RequestID)
	if err != nil {
		return Context{}, err
	}
	correlationID, err := ParseID(input.CorrelationID)
	if err != nil {
		return Context{}, err
	}
	if !validOpaqueToken(input.Subject, 1, 128) ||
		!validOpaqueToken(input.Provider, 1, 64) ||
		!validOpaqueToken(input.AssertionID, 1, 128) {
		return Context{}, &Error{Kind: ErrorMalformed, Cause: errors.New("authentication identity text is invalid")}
	}

	authenticatedAt, err := time.Parse(time.RFC3339Nano, input.AuthenticatedAt)
	if err != nil || input.AuthenticatedAt != authenticatedAt.UTC().Format(time.RFC3339Nano) {
		return Context{}, &Error{Kind: ErrorMalformed, Cause: errors.New("authentication time is invalid")}
	}
	now := v.now().UTC()
	if authenticatedAt.Before(now.Add(-MaximumHandoffAge)) || authenticatedAt.After(now.Add(MaximumFutureSkew)) {
		return Context{}, &Error{Kind: ErrorStale, Cause: errors.New("authentication time is outside the accepted window")}
	}

	nonceBytes, err := base64.RawURLEncoding.DecodeString(input.Nonce)
	if err != nil || len(nonceBytes) < 16 || len(nonceBytes) > 32 || base64.RawURLEncoding.EncodeToString(nonceBytes) != input.Nonce {
		return Context{}, &Error{Kind: ErrorMalformed, Cause: errors.New("nonce is invalid")}
	}

	suppliedSignature, err := parseSignature(input.Signature)
	if err != nil {
		return Context{}, err
	}
	canonical := canonicalInput(input)
	mac := hmac.New(sha256.New, v.key)
	_, _ = mac.Write([]byte(canonical))
	expectedSignature := mac.Sum(nil)
	if !hmac.Equal(suppliedSignature, expectedSignature) {
		return Context{}, &Error{Kind: ErrorInvalid, Cause: errors.New("signature mismatch")}
	}

	replayKey := sha256.Sum256([]byte(input.RequestID + "\n" + input.Nonce + "\n" + input.Signature))
	expiresAt := authenticatedAt.Add(MaximumHandoffAge + MaximumFutureSkew)
	if err := v.recordReplay(replayKey, now, expiresAt); err != nil {
		return Context{}, err
	}

	return Context{
		RequestID:       requestID,
		CorrelationID:   correlationID,
		Subject:         input.Subject,
		Provider:        input.Provider,
		AssertionID:     input.AssertionID,
		AuthenticatedAt: authenticatedAt,
		ReceivedAt:      now,
	}, nil
}

func (v *Verifier) recordReplay(key [sha256.Size]byte, now, expiresAt time.Time) error {
	v.mu.Lock()
	defer v.mu.Unlock()

	for existingKey, expiration := range v.replays {
		if !expiration.After(now) {
			delete(v.replays, existingKey)
		}
	}
	if _, exists := v.replays[key]; exists {
		return &Error{Kind: ErrorReplay, Cause: errors.New("handoff was already consumed")}
	}
	if len(v.replays) >= MaximumReplayEntries {
		return &Error{Kind: ErrorCapacity, Cause: errors.New("replay window is at capacity")}
	}
	v.replays[key] = expiresAt
	return nil
}

func canonicalInput(input Input) string {
	return strings.Join([]string{
		"ISSP-HANDOFF-V1",
		input.Method,
		input.Path,
		input.RequestID,
		input.CorrelationID,
		input.Subject,
		input.Provider,
		input.AssertionID,
		input.AuthenticatedAt,
		input.Nonce,
		hex.EncodeToString(input.BodyDigest[:]),
	}, "\n")
}

func parseSignature(value string) ([]byte, error) {
	if !strings.HasPrefix(value, "v1=") || len(value) != 67 {
		return nil, &Error{Kind: ErrorMalformed, Cause: errors.New("signature format is invalid")}
	}
	hexText := strings.TrimPrefix(value, "v1=")
	if strings.ToLower(hexText) != hexText {
		return nil, &Error{Kind: ErrorMalformed, Cause: errors.New("signature must use lowercase hexadecimal")}
	}
	decoded, err := hex.DecodeString(hexText)
	if err != nil || len(decoded) != sha256.Size {
		return nil, &Error{Kind: ErrorMalformed, Cause: errors.New("signature text is invalid")}
	}
	return decoded, nil
}

func validOpaqueToken(value string, minimum, maximum int) bool {
	if len(value) < minimum || len(value) > maximum || strings.TrimSpace(value) != value {
		return false
	}
	for _, character := range value {
		if (character >= 'a' && character <= 'z') ||
			(character >= 'A' && character <= 'Z') ||
			(character >= '0' && character <= '9') ||
			strings.ContainsRune("._:@/-", character) {
			continue
		}
		return false
	}
	return true
}
