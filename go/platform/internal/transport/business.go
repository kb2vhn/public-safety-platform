package transport

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/authentication"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/foundation"
)

const (
	AuthorizationPolicyBindingPath = "/v1/foundation/authorization-policy-bindings"
	maximumBusinessRequestBody     = 1024
	businessRequestTimeout         = 4 * time.Second

	HeaderRequestID       = "X-Iron-Signal-Request-ID"
	HeaderCorrelationID   = "X-Iron-Signal-Correlation-ID"
	HeaderSubject         = "X-Iron-Signal-Subject"
	HeaderProvider        = "X-Iron-Signal-Provider"
	HeaderAssertionID     = "X-Iron-Signal-Assertion-ID"
	HeaderAuthenticatedAt = "X-Iron-Signal-Authenticated-At"
	HeaderNonce           = "X-Iron-Signal-Nonce"
	HeaderSignature       = "X-Iron-Signal-Signature"
)

var authenticationHeaders = []string{
	HeaderRequestID,
	HeaderCorrelationID,
	HeaderSubject,
	HeaderProvider,
	HeaderAssertionID,
	HeaderAuthenticatedAt,
	HeaderNonce,
	HeaderSignature,
}

// HandoffVerifier verifies trusted authentication context without granting
// authorization for the protected operation.
type HandoffVerifier interface {
	Verify(authentication.Input) (authentication.Context, error)
}

// AuthorizationPolicyBinder is the exact Step 5 protected operation consumed
// by the Step 6 transport boundary.
type AuthorizationPolicyBinder interface {
	BindAuthorizationPolicy(context.Context, foundation.DecisionID) (foundation.PolicyBindingResult, error)
}

// BusinessHandler owns one bounded authenticated route. It does not interpret
// authenticated identity as authorization and passes only DecisionID to the
// accepted Step 5 adapter.
type BusinessHandler struct {
	verifier  HandoffVerifier
	binder    AuthorizationPolicyBinder
	semaphore chan struct{}
}

// NewBusinessHandler creates the exact Step 6 route handler.
func NewBusinessHandler(
	verifier HandoffVerifier,
	binder AuthorizationPolicyBinder,
	maximumConcurrent int32,
) (*BusinessHandler, error) {
	if verifier == nil || binder == nil || maximumConcurrent < 1 || maximumConcurrent > 32 {
		return nil, errors.New("business transport dependencies are outside the accepted boundary")
	}
	return &BusinessHandler{
		verifier:  verifier,
		binder:    binder,
		semaphore: make(chan struct{}, maximumConcurrent),
	}, nil
}

func (handler *BusinessHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != AuthorizationPolicyBindingPath || r.URL.RawQuery != "" {
		writeBusinessError(w, http.StatusNotFound, "", "", "NOT_FOUND")
		return
	}
	if r.Method != http.MethodPost {
		w.Header().Set("Allow", http.MethodPost)
		writeBusinessError(w, http.StatusMethodNotAllowed, "", "", "METHOD_NOT_ALLOWED")
		return
	}
	if hasUntrustedProxyHeader(r) {
		writeBusinessError(w, http.StatusBadRequest, "", "", "INVALID_REQUEST")
		return
	}
	if !acceptedJSONContentType(r.Header.Get("Content-Type")) {
		writeBusinessError(w, http.StatusUnsupportedMediaType, "", "", "UNSUPPORTED_MEDIA_TYPE")
		return
	}

	select {
	case handler.semaphore <- struct{}{}:
		defer func() { <-handler.semaphore }()
	default:
		writeBusinessError(w, http.StatusServiceUnavailable, "", "", "SERVICE_BUSY")
		return
	}

	requestContext, cancel := context.WithTimeout(r.Context(), businessRequestTimeout)
	defer cancel()

	body, err := readBoundedBody(w, r)
	if err != nil {
		var maxBytesError *http.MaxBytesError
		if errors.As(err, &maxBytesError) {
			writeBusinessError(w, http.StatusRequestEntityTooLarge, "", "", "REQUEST_TOO_LARGE")
			return
		}
		writeBusinessError(w, http.StatusBadRequest, "", "", "INVALID_REQUEST")
		return
	}

	input, err := authenticationInput(r, body)
	if err != nil {
		writeBusinessError(w, http.StatusUnauthorized, "", "", "AUTHENTICATION_REQUIRED")
		return
	}
	authenticatedContext, err := handler.verifier.Verify(input)
	if err != nil {
		var handoffError *authentication.Error
		if errors.As(err, &handoffError) && handoffError.Kind == authentication.ErrorCapacity {
			writeBusinessError(w, http.StatusServiceUnavailable, "", "", "SERVICE_BUSY")
			return
		}
		writeBusinessError(w, http.StatusUnauthorized, "", "", "AUTHENTICATION_REQUIRED")
		return
	}

	decisionID, err := decodeBindingRequest(body)
	if err != nil {
		writeBusinessError(
			w,
			http.StatusBadRequest,
			authenticatedContext.RequestID.String(),
			authenticatedContext.CorrelationID.String(),
			"INVALID_REQUEST",
		)
		return
	}

	result, err := handler.binder.BindAuthorizationPolicy(requestContext, decisionID)
	if err != nil {
		statusCode := http.StatusInternalServerError
		code := "FOUNDATION_OPERATION_FAILED"
		if errors.Is(err, context.DeadlineExceeded) {
			statusCode = http.StatusGatewayTimeout
			code = "OPERATION_TIMEOUT"
		} else if errors.Is(err, context.Canceled) {
			statusCode = http.StatusServiceUnavailable
			code = "OPERATION_CANCELED"
		}
		writeBusinessError(
			w,
			statusCode,
			authenticatedContext.RequestID.String(),
			authenticatedContext.CorrelationID.String(),
			code,
		)
		return
	}

	writeBusinessJSON(w, http.StatusOK, businessEnvelope{
		RequestID:     authenticatedContext.RequestID.String(),
		CorrelationID: authenticatedContext.CorrelationID.String(),
		Result: &businessResult{
			DecisionID: result.DecisionID.String(),
			ReasonCode: string(result.ReasonCode),
		},
	})
}

func authenticationInput(r *http.Request, body []byte) (authentication.Input, error) {
	values := make(map[string]string, len(authenticationHeaders))
	for _, headerName := range authenticationHeaders {
		headerValues := r.Header.Values(headerName)
		if len(headerValues) != 1 || strings.TrimSpace(headerValues[0]) == "" {
			return authentication.Input{}, errors.New("required authentication header is missing or repeated")
		}
		values[headerName] = headerValues[0]
	}
	return authentication.Input{
		Method:          r.Method,
		Path:            r.URL.Path,
		BodyDigest:      sha256.Sum256(body),
		RequestID:       values[HeaderRequestID],
		CorrelationID:   values[HeaderCorrelationID],
		Subject:         values[HeaderSubject],
		Provider:        values[HeaderProvider],
		AssertionID:     values[HeaderAssertionID],
		AuthenticatedAt: values[HeaderAuthenticatedAt],
		Nonce:           values[HeaderNonce],
		Signature:       values[HeaderSignature],
	}, nil
}

func decodeBindingRequest(body []byte) (foundation.DecisionID, error) {
	var payload struct {
		DecisionID string `json:"decision_id"`
	}
	decoder := json.NewDecoder(strings.NewReader(string(body)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&payload); err != nil {
		return foundation.DecisionID{}, err
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return foundation.DecisionID{}, errors.New("request body contains trailing content")
	}
	return foundation.ParseDecisionID(payload.DecisionID)
}

func readBoundedBody(w http.ResponseWriter, r *http.Request) ([]byte, error) {
	defer r.Body.Close()
	reader := http.MaxBytesReader(w, r.Body, maximumBusinessRequestBody)
	return io.ReadAll(reader)
}

func acceptedJSONContentType(value string) bool {
	mediaType, parameters, err := mime.ParseMediaType(value)
	if err != nil || mediaType != "application/json" {
		return false
	}
	for name, parameter := range parameters {
		if strings.ToLower(name) != "charset" || strings.ToLower(parameter) != "utf-8" {
			return false
		}
	}
	return true
}

func hasUntrustedProxyHeader(r *http.Request) bool {
	for _, name := range []string{"Forwarded", "X-Forwarded-For", "X-Forwarded-Host", "X-Forwarded-Proto", "X-Real-IP"} {
		if len(r.Header.Values(name)) != 0 {
			return true
		}
	}
	return false
}

type businessEnvelope struct {
	RequestID     string          `json:"request_id,omitempty"`
	CorrelationID string          `json:"correlation_id,omitempty"`
	Result        *businessResult `json:"result,omitempty"`
	Error         *businessError  `json:"error,omitempty"`
}

type businessResult struct {
	DecisionID string `json:"decision_id"`
	ReasonCode string `json:"reason_code"`
}

type businessError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func writeBusinessError(w http.ResponseWriter, statusCode int, requestID, correlationID, code string) {
	writeBusinessJSON(w, statusCode, businessEnvelope{
		RequestID:     requestID,
		CorrelationID: correlationID,
		Error: &businessError{
			Code:    code,
			Message: "request rejected",
		},
	})
}

func writeBusinessJSON(w http.ResponseWriter, statusCode int, payload businessEnvelope) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	if payload.RequestID != "" {
		w.Header().Set(HeaderRequestID, payload.RequestID)
	}
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(payload)
}

// BusinessServer is the separately bounded loopback-only business HTTP server.
type BusinessServer struct {
	listener net.Listener
	http     *http.Server
}

// ListenBusiness binds the validated Step 6 business address.
func ListenBusiness(address string, handler http.Handler) (*BusinessServer, error) {
	listener, err := net.Listen("tcp", address)
	if err != nil {
		return nil, err
	}
	server := &http.Server{
		Handler:           handler,
		ReadHeaderTimeout: 2 * time.Second,
		ReadTimeout:       5 * time.Second,
		WriteTimeout:      5 * time.Second,
		IdleTimeout:       30 * time.Second,
		MaxHeaderBytes:    8 * 1024,
	}
	return &BusinessServer{listener: listener, http: server}, nil
}

// Addr returns the effective local business address.
func (s *BusinessServer) Addr() string { return s.listener.Addr().String() }

// Serve blocks until shutdown or an unexpected listener failure.
func (s *BusinessServer) Serve() error {
	err := s.http.Serve(s.listener)
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

// Shutdown stops accepting business requests and waits within the supplied context.
func (s *BusinessServer) Shutdown(ctx context.Context) error { return s.http.Shutdown(ctx) }
