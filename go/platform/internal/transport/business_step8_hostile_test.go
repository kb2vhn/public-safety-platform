package transport

import (
	"bufio"
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/foundation"
)

func TestPhase6Step8DuplicateAuthenticationHeadersFailClosed(t *testing.T) {
	now := time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC)
	binder := &countingPolicyBinder{}
	handler := newBusinessTestHandler(t, now, binder, 2)
	body := `{"decision_id":"33333333-3333-3333-3333-333333333333"}`

	for index, headerName := range authenticationHeaders {
		t.Run(headerName, func(t *testing.T) {
			request := signedBusinessRequest(t, now, body, "phase8-duplicate-"+string(rune('a'+index)))
			request.Header.Add(headerName, request.Header.Get(headerName))
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			if response.Code != http.StatusUnauthorized {
				t.Fatalf("status = %d body=%s", response.Code, response.Body.String())
			}
			assertStep8ErrorEnvelope(t, response, "AUTHENTICATION_REQUIRED")
		})
	}
	if binder.calls.Load() != 0 {
		t.Fatalf("binder calls = %d, want 0", binder.calls.Load())
	}
}

func TestPhase6Step8BodyAndSignedIdentityTamperingFailBeforeAdapter(t *testing.T) {
	now := time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC)
	binder := &countingPolicyBinder{}
	handler := newBusinessTestHandler(t, now, binder, 2)
	originalBody := `{"decision_id":"33333333-3333-3333-3333-333333333333"}`

	request := signedBusinessRequest(t, now, originalBody, "phase8-body-tamper")
	request.Body = http.NoBody
	request.ContentLength = 0
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("tampered body status = %d body=%s", response.Code, response.Body.String())
	}

	identityRequest := signedBusinessRequest(t, now, originalBody, "phase8-identity-tamper")
	identityRequest.Header.Set(HeaderSubject, "identity:attacker")
	identityResponse := httptest.NewRecorder()
	handler.ServeHTTP(identityResponse, identityRequest)
	if identityResponse.Code != http.StatusUnauthorized {
		t.Fatalf("tampered identity status = %d body=%s", identityResponse.Code, identityResponse.Body.String())
	}

	if binder.calls.Load() != 0 {
		t.Fatalf("binder calls = %d, want 0", binder.calls.Load())
	}
}

func TestPhase6Step8EveryProxyAuthorityHeaderIsRejected(t *testing.T) {
	now := time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC)
	binder := &countingPolicyBinder{}
	handler := newBusinessTestHandler(t, now, binder, 2)
	body := `{"decision_id":"33333333-3333-3333-3333-333333333333"}`

	for index, headerName := range []string{
		"Forwarded",
		"X-Forwarded-For",
		"X-Forwarded-Host",
		"X-Forwarded-Proto",
		"X-Real-IP",
	} {
		t.Run(headerName, func(t *testing.T) {
			request := signedBusinessRequest(t, now, body, "phase8-proxy-"+string(rune('a'+index)))
			request.Header.Set(headerName, "attacker.example")
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			if response.Code != http.StatusBadRequest {
				t.Fatalf("status = %d body=%s", response.Code, response.Body.String())
			}
			assertStep8ErrorEnvelope(t, response, "INVALID_REQUEST")
		})
	}
	if binder.calls.Load() != 0 {
		t.Fatalf("binder calls = %d, want 0", binder.calls.Load())
	}
}

func TestPhase6Step8ParentDeadlineCancelsFoundationOperation(t *testing.T) {
	now := time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC)
	binder := &deadlinePolicyBinder{}
	handler := newBusinessTestHandler(t, now, binder, 1)
	body := `{"decision_id":"33333333-3333-3333-3333-333333333333"}`
	request := signedBusinessRequest(t, now, body, "phase8-parent-deadline")
	requestContext, cancel := context.WithTimeout(request.Context(), 30*time.Millisecond)
	defer cancel()
	request = request.WithContext(requestContext)

	response := httptest.NewRecorder()
	started := time.Now()
	handler.ServeHTTP(response, request)
	if elapsed := time.Since(started); elapsed > time.Second {
		t.Fatalf("request cancellation was not bounded: %s", elapsed)
	}
	if response.Code != http.StatusGatewayTimeout {
		t.Fatalf("status = %d body=%s", response.Code, response.Body.String())
	}
	assertStep8ErrorEnvelope(t, response, "OPERATION_TIMEOUT")
}

func TestPhase6Step8RouteAndMediaRejectionDoNotConsumeHandoff(t *testing.T) {
	now := time.Date(2026, 7, 15, 12, 0, 0, 0, time.UTC)
	binder := &countingPolicyBinder{
		result: foundation.PolicyBindingResult{
			DecisionID: mustDecisionID(t, "33333333-3333-3333-3333-333333333333"),
			ReasonCode: foundation.AuthorizationPolicySelected,
		},
	}
	handler := newBusinessTestHandler(t, now, binder, 1)
	body := `{"decision_id":"33333333-3333-3333-3333-333333333333"}`

	wrongRoute := signedBusinessRequest(t, now, body, "phase8-unconsumed-route")
	wrongRoute.URL.Path = "/v1/foundation/other"
	wrongRouteResponse := httptest.NewRecorder()
	handler.ServeHTTP(wrongRouteResponse, wrongRoute)
	if wrongRouteResponse.Code != http.StatusNotFound {
		t.Fatalf("wrong-route status = %d", wrongRouteResponse.Code)
	}

	valid := signedBusinessRequest(t, now, body, "phase8-unconsumed-route")
	validResponse := httptest.NewRecorder()
	handler.ServeHTTP(validResponse, valid)
	if validResponse.Code != http.StatusOK {
		t.Fatalf("valid status = %d body=%s", validResponse.Code, validResponse.Body.String())
	}

	unsupported := signedBusinessRequest(t, now, body, "phase8-unconsumed-media")
	unsupported.Header.Set("Content-Type", "application/json; charset=iso-8859-1")
	unsupportedResponse := httptest.NewRecorder()
	handler.ServeHTTP(unsupportedResponse, unsupported)
	if unsupportedResponse.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("unsupported-media status = %d", unsupportedResponse.Code)
	}

	validMedia := signedBusinessRequest(t, now, body, "phase8-unconsumed-media")
	validMediaResponse := httptest.NewRecorder()
	handler.ServeHTTP(validMediaResponse, validMedia)
	if validMediaResponse.Code != http.StatusOK {
		t.Fatalf("valid-media status = %d body=%s", validMediaResponse.Code, validMediaResponse.Body.String())
	}

	if binder.calls.Load() != 2 {
		t.Fatalf("binder calls = %d, want 2", binder.calls.Load())
	}
}

func TestPhase6Step8BusinessServerRejectsOversizedHeaders(t *testing.T) {
	var handlerCalls atomic.Int32
	server, err := ListenBusiness("127.0.0.1:0", http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		handlerCalls.Add(1)
		w.WriteHeader(http.StatusNoContent)
	}))
	if err != nil {
		t.Fatalf("ListenBusiness() error = %v", err)
	}
	serveResult := make(chan error, 1)
	go func() { serveResult <- server.Serve() }()

	connection, err := net.DialTimeout("tcp", server.Addr(), time.Second)
	if err != nil {
		t.Fatalf("DialTimeout() error = %v", err)
	}
	_, err = connection.Write([]byte(
		"GET / HTTP/1.1\r\nHost: " + server.Addr() + "\r\nX-Oversized: " + strings.Repeat("a", 20*1024) + "\r\n\r\n",
	))
	if err != nil {
		_ = connection.Close()
		t.Fatalf("Write() error = %v", err)
	}
	_ = connection.SetReadDeadline(time.Now().Add(2 * time.Second))
	statusLine, readErr := bufio.NewReader(connection).ReadString('\n')
	_ = connection.Close()
	if readErr != nil {
		t.Fatalf("ReadString() error = %v", readErr)
	}
	if !strings.Contains(statusLine, " 431 ") {
		t.Fatalf("status line = %q, want 431", statusLine)
	}
	if handlerCalls.Load() != 0 {
		t.Fatalf("handler calls = %d, want 0", handlerCalls.Load())
	}

	shutdownContext, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownContext); err != nil {
		t.Fatalf("Shutdown() error = %v", err)
	}
	select {
	case serveErr := <-serveResult:
		if serveErr != nil {
			t.Fatalf("Serve() error = %v", serveErr)
		}
	case <-time.After(time.Second):
		t.Fatal("Serve() did not stop")
	}
}

type countingPolicyBinder struct {
	calls  atomic.Int32
	result foundation.PolicyBindingResult
	err    error
}

func (binder *countingPolicyBinder) BindAuthorizationPolicy(context.Context, foundation.DecisionID) (foundation.PolicyBindingResult, error) {
	binder.calls.Add(1)
	return binder.result, binder.err
}

type deadlinePolicyBinder struct{}

func (*deadlinePolicyBinder) BindAuthorizationPolicy(ctx context.Context, _ foundation.DecisionID) (foundation.PolicyBindingResult, error) {
	<-ctx.Done()
	return foundation.PolicyBindingResult{}, ctx.Err()
}

func assertStep8ErrorEnvelope(t *testing.T, response *httptest.ResponseRecorder, code string) {
	t.Helper()
	body := response.Body.String()
	if !strings.Contains(body, `"code":"`+code+`"`) || !strings.Contains(body, `"message":"request rejected"`) {
		t.Fatalf("error envelope = %q", body)
	}
	if strings.Contains(strings.ToLower(body), "postgres") || strings.Contains(body, "attacker.example") {
		t.Fatalf("error envelope disclosed protected details: %q", body)
	}
	if response.Header().Get("Cache-Control") != "no-store" || response.Header().Get("X-Content-Type-Options") != "nosniff" {
		t.Fatalf("response safety headers = %#v", response.Header())
	}
}
