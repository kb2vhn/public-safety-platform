package transport

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/authentication"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/foundation"
)

var businessTestKey = []byte("0123456789abcdef0123456789abcdef")

func TestBusinessHandlerReturnsAuthenticatedPolicyBindingResult(t *testing.T) {
	now := time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC)
	handler := newBusinessTestHandler(t, now, &testPolicyBinder{
		result: foundation.PolicyBindingResult{
			DecisionID: mustDecisionID(t, "33333333-3333-3333-3333-333333333333"),
			ReasonCode: foundation.AuthorizationPolicySelected,
		},
	}, 2)

	body := `{"decision_id":"33333333-3333-3333-3333-333333333333"}`
	request := signedBusinessRequest(t, now, body, "nonce-success-01")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d body=%s", response.Code, response.Body.String())
	}
	var envelope businessEnvelope
	if err := json.Unmarshal(response.Body.Bytes(), &envelope); err != nil {
		t.Fatalf("Unmarshal() error = %v", err)
	}
	if envelope.Result == nil || envelope.Result.ReasonCode != string(foundation.AuthorizationPolicySelected) {
		t.Fatalf("envelope = %#v", envelope)
	}
	if envelope.RequestID != "11111111-1111-1111-1111-111111111111" ||
		envelope.CorrelationID != "22222222-2222-2222-2222-222222222222" {
		t.Fatalf("correlation envelope = %#v", envelope)
	}
}

func TestBusinessHandlerRejectsReplayAndSpoofedProxyHeaders(t *testing.T) {
	now := time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC)
	handler := newBusinessTestHandler(t, now, &testPolicyBinder{
		result: foundation.PolicyBindingResult{
			DecisionID: mustDecisionID(t, "33333333-3333-3333-3333-333333333333"),
			ReasonCode: foundation.AuthorizationPolicySelected,
		},
	}, 2)
	body := `{"decision_id":"33333333-3333-3333-3333-333333333333"}`
	request := signedBusinessRequest(t, now, body, "nonce-replay-0001")

	first := httptest.NewRecorder()
	handler.ServeHTTP(first, request.Clone(context.Background()))
	if first.Code != http.StatusOK {
		t.Fatalf("first status = %d", first.Code)
	}
	second := httptest.NewRecorder()
	handler.ServeHTTP(second, request.Clone(context.Background()))
	if second.Code != http.StatusUnauthorized || strings.Contains(second.Body.String(), "replay") {
		t.Fatalf("replay status=%d body=%q", second.Code, second.Body.String())
	}

	spoofed := signedBusinessRequest(t, now, body, "nonce-proxy-00001")
	spoofed.Header.Set("X-Forwarded-For", "198.51.100.1")
	spoofedResponse := httptest.NewRecorder()
	handler.ServeHTTP(spoofedResponse, spoofed)
	if spoofedResponse.Code != http.StatusBadRequest {
		t.Fatalf("spoofed proxy status = %d", spoofedResponse.Code)
	}
}

func TestBusinessHandlerEnforcesMethodMediaBodyAndRouteLimits(t *testing.T) {
	now := time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC)
	handler := newBusinessTestHandler(t, now, &testPolicyBinder{}, 1)

	tests := []struct {
		name    string
		request *http.Request
		status  int
	}{
		{name: "route", request: httptest.NewRequest(http.MethodPost, "/wrong", strings.NewReader(`{}`)), status: http.StatusNotFound},
		{name: "method", request: httptest.NewRequest(http.MethodGet, AuthorizationPolicyBindingPath, nil), status: http.StatusMethodNotAllowed},
		{name: "media", request: httptest.NewRequest(http.MethodPost, AuthorizationPolicyBindingPath, strings.NewReader(`{}`)), status: http.StatusUnsupportedMediaType},
		{name: "large", request: requestWithContentType(strings.Repeat("x", maximumBusinessRequestBody+1)), status: http.StatusRequestEntityTooLarge},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, test.request)
			if response.Code != test.status {
				t.Fatalf("status = %d, want %d body=%s", response.Code, test.status, response.Body.String())
			}
		})
	}
}

func TestBusinessHandlerRejectsMalformedBodyAfterAuthentication(t *testing.T) {
	now := time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC)
	handler := newBusinessTestHandler(t, now, &testPolicyBinder{}, 1)
	for index, body := range []string{
		`{"decision_id":"33333333-3333-3333-3333-333333333333","extra":true}`,
		`{"decision_id":"not-a-uuid"}`,
		`{"decision_id":"33333333-3333-3333-3333-333333333333"}{}`,
	} {
		request := signedBusinessRequest(t, now, body, "nonce-malformed-"+string(rune('a'+index))+"001")
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		if response.Code != http.StatusBadRequest || strings.Contains(response.Body.String(), "not-a-uuid") {
			t.Fatalf("body=%q status=%d response=%q", body, response.Code, response.Body.String())
		}
	}
}

func TestBusinessHandlerBoundsConcurrencyWithoutQueueing(t *testing.T) {
	now := time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC)
	entered := make(chan struct{})
	release := make(chan struct{})
	binder := &blockingPolicyBinder{entered: entered, release: release}
	handler := newBusinessTestHandler(t, now, binder, 1)
	body := `{"decision_id":"33333333-3333-3333-3333-333333333333"}`

	firstDone := make(chan *httptest.ResponseRecorder, 1)
	go func() {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, signedBusinessRequest(t, now, body, "nonce-concurrent01"))
		firstDone <- response
	}()
	select {
	case <-entered:
	case <-time.After(time.Second):
		t.Fatal("first request did not enter binder")
	}

	second := httptest.NewRecorder()
	handler.ServeHTTP(second, signedBusinessRequest(t, now, body, "nonce-concurrent02"))
	if second.Code != http.StatusServiceUnavailable {
		t.Fatalf("second status = %d body=%s", second.Code, second.Body.String())
	}
	close(release)
	select {
	case first := <-firstDone:
		if first.Code != http.StatusOK {
			t.Fatalf("first status = %d", first.Code)
		}
	case <-time.After(time.Second):
		t.Fatal("first request did not complete")
	}
}

func TestBusinessHandlerMapsOperationErrorsWithoutDisclosure(t *testing.T) {
	now := time.Date(2026, 7, 14, 23, 0, 0, 0, time.UTC)
	for _, test := range []struct {
		name   string
		err    error
		status int
		code   string
	}{
		{name: "deadline", err: context.DeadlineExceeded, status: http.StatusGatewayTimeout, code: "OPERATION_TIMEOUT"},
		{name: "canceled", err: context.Canceled, status: http.StatusServiceUnavailable, code: "OPERATION_CANCELED"},
		{name: "internal", err: errors.New("postgresql://secret@example"), status: http.StatusInternalServerError, code: "FOUNDATION_OPERATION_FAILED"},
	} {
		t.Run(test.name, func(t *testing.T) {
			handler := newBusinessTestHandler(t, now, &testPolicyBinder{err: test.err}, 1)
			body := `{"decision_id":"33333333-3333-3333-3333-333333333333"}`
			request := signedBusinessRequest(t, now, body, "nonce-error-"+test.name+"-01")
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			if response.Code != test.status || !strings.Contains(response.Body.String(), test.code) {
				t.Fatalf("status=%d body=%q", response.Code, response.Body.String())
			}
			if strings.Contains(response.Body.String(), "postgresql://") {
				t.Fatalf("response disclosed cause: %q", response.Body.String())
			}
		})
	}
}

type testPolicyBinder struct {
	result foundation.PolicyBindingResult
	err    error
}

func (binder *testPolicyBinder) BindAuthorizationPolicy(context.Context, foundation.DecisionID) (foundation.PolicyBindingResult, error) {
	return binder.result, binder.err
}

type blockingPolicyBinder struct {
	entered chan struct{}
	release chan struct{}
	once    sync.Once
}

func (binder *blockingPolicyBinder) BindAuthorizationPolicy(_ context.Context, decisionID foundation.DecisionID) (foundation.PolicyBindingResult, error) {
	binder.once.Do(func() { close(binder.entered) })
	<-binder.release
	return foundation.PolicyBindingResult{DecisionID: decisionID, ReasonCode: foundation.AuthorizationPolicySelected}, nil
}

func newBusinessTestHandler(t *testing.T, now time.Time, binder AuthorizationPolicyBinder, maximumConcurrent int32) *BusinessHandler {
	t.Helper()
	verifier, err := authentication.NewVerifier(businessTestKey, func() time.Time { return now })
	if err != nil {
		t.Fatalf("NewVerifier() error = %v", err)
	}
	handler, err := NewBusinessHandler(verifier, binder, maximumConcurrent)
	if err != nil {
		t.Fatalf("NewBusinessHandler() error = %v", err)
	}
	return handler
}

func signedBusinessRequest(t *testing.T, now time.Time, body, nonceText string) *http.Request {
	t.Helper()
	request := httptest.NewRequest(http.MethodPost, AuthorizationPolicyBindingPath, strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set(HeaderRequestID, "11111111-1111-1111-1111-111111111111")
	request.Header.Set(HeaderCorrelationID, "22222222-2222-2222-2222-222222222222")
	request.Header.Set(HeaderSubject, "identity:example-user")
	request.Header.Set(HeaderProvider, "gateway:test")
	request.Header.Set(HeaderAssertionID, "assertion:test-1")
	request.Header.Set(HeaderAuthenticatedAt, now.Format(time.RFC3339Nano))
	nonceDigest := sha256.Sum256([]byte(nonceText))
	request.Header.Set(HeaderNonce, base64.RawURLEncoding.EncodeToString(nonceDigest[:16]))

	digest := sha256.Sum256([]byte(body))
	canonical := strings.Join([]string{
		"ISSP-HANDOFF-V1",
		http.MethodPost,
		AuthorizationPolicyBindingPath,
		request.Header.Get(HeaderRequestID),
		request.Header.Get(HeaderCorrelationID),
		request.Header.Get(HeaderSubject),
		request.Header.Get(HeaderProvider),
		request.Header.Get(HeaderAssertionID),
		request.Header.Get(HeaderAuthenticatedAt),
		request.Header.Get(HeaderNonce),
		hex.EncodeToString(digest[:]),
	}, "\n")
	mac := hmac.New(sha256.New, businessTestKey)
	_, _ = mac.Write([]byte(canonical))
	request.Header.Set(HeaderSignature, "v1="+hex.EncodeToString(mac.Sum(nil)))
	return request
}

func requestWithContentType(body string) *http.Request {
	request := httptest.NewRequest(http.MethodPost, AuthorizationPolicyBindingPath, strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	return request
}

func mustDecisionID(t *testing.T, value string) foundation.DecisionID {
	t.Helper()
	id, err := foundation.ParseDecisionID(value)
	if err != nil {
		t.Fatalf("ParseDecisionID() error = %v", err)
	}
	return id
}
