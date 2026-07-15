package workers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

func TestPhase6Step8RelayHostileResponsesRemainBoundedAndRedacted(t *testing.T) {
	var proxyCalls atomic.Int32
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		proxyCalls.Add(1)
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer proxy.Close()
	t.Setenv("HTTP_PROXY", proxy.URL)
	t.Setenv("HTTPS_PROXY", proxy.URL)

	var redirectCalls atomic.Int32
	redirectTarget := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		redirectCalls.Add(1)
		w.WriteHeader(http.StatusNoContent)
	}))
	defer redirectTarget.Close()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/success":
			if r.Header.Get("Idempotency-Key") != "step8-delivery" || r.Header.Get("Authorization") == "" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}
			w.WriteHeader(http.StatusNoContent)
		case "/timeout":
			select {
			case <-r.Context().Done():
			case <-time.After(1200 * time.Millisecond):
			}
		case "/disconnect":
			hijacker, ok := w.(http.Hijacker)
			if !ok {
				w.WriteHeader(http.StatusInternalServerError)
				return
			}
			connection, _, err := hijacker.Hijack()
			if err == nil {
				_ = connection.Close()
			}
		case "/redirect":
			http.Redirect(w, r, redirectTarget.URL+"/credential-capture", http.StatusTemporaryRedirect)
		case "/unavailable":
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write(bytes.Repeat([]byte("secret-upstream-body"), 1024))
		case "/rejected":
			w.WriteHeader(http.StatusBadRequest)
			_, _ = io.WriteString(w, "protected rejection detail")
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer server.Close()

	token := []byte("0123456789abcdef0123456789abcdef")
	envelope := relayEnvelope{
		Version:        deliveryEnvelopeVersion,
		Kind:           integrationKind,
		DeliveryID:     "step8-delivery",
		AttemptNumber:  3,
		ClaimExpiresAt: time.Now().UTC().Add(time.Minute),
		Metadata:       json.RawMessage(`{"destination_reference":"http://attacker.invalid"}`),
		Payload:        json.RawMessage(`{"value":1}`),
	}

	tests := []struct {
		path       string
		diagnostic string
	}{
		{path: "/success", diagnostic: "delivery_no_error"},
		{path: "/timeout", diagnostic: "delivery_timeout"},
		{path: "/disconnect", diagnostic: "delivery_network_error"},
		{path: "/redirect", diagnostic: "delivery_network_error"},
		{path: "/unavailable", diagnostic: "delivery_relay_unavailable"},
		{path: "/rejected", diagnostic: "delivery_relay_rejected"},
	}
	for _, testCase := range tests {
		t.Run(testCase.path, func(t *testing.T) {
			cfg := testDeliveryConfig(server.URL + testCase.path)
			cfg.RequestTimeout = time.Second
			client, err := newHTTPRelayClient(database.IntegrationDeliveryWorker, cfg, token)
			if err != nil {
				t.Fatalf("newHTTPRelayClient() error = %v", err)
			}
			deliveryErr := client.Deliver(context.Background(), envelope)
			client.Close()
			if got := Diagnostic(deliveryErr); got != testCase.diagnostic {
				t.Fatalf("Diagnostic() = %q, want %q error=%v", got, testCase.diagnostic, deliveryErr)
			}
			if deliveryErr != nil && (contains(deliveryErr.Error(), "secret-upstream-body") || contains(deliveryErr.Error(), "protected rejection detail") || contains(deliveryErr.Error(), redirectTarget.URL)) {
				t.Fatalf("error disclosed relay detail: %q", deliveryErr)
			}
		})
	}
	if proxyCalls.Load() != 0 {
		t.Fatalf("ambient proxy calls = %d, want 0", proxyCalls.Load())
	}
	if redirectCalls.Load() != 0 {
		t.Fatalf("redirect target calls = %d, want 0", redirectCalls.Load())
	}
}

func TestPhase6Step8RunnerStopsClaimingImmediatelyOnCancellation(t *testing.T) {
	var cycles atomic.Int32
	ctx, cancel := context.WithCancel(context.Background())
	cycle := func(context.Context) error {
		if cycles.Add(1) == 1 {
			cancel()
		}
		return errors.New("postgresql://user:secret@database/should-not-leak")
	}
	var logBuffer bytes.Buffer
	logger := slog.New(slog.NewTextHandler(&logBuffer, nil))
	if err := runLoop(ctx, 10*time.Millisecond, cycle, logger, "integration"); err != nil {
		t.Fatalf("runLoop() error = %v", err)
	}
	if cycles.Load() != 1 {
		t.Fatalf("cycles = %d, want 1", cycles.Load())
	}
	if contains(logBuffer.String(), "postgresql://") || contains(logBuffer.String(), "secret") {
		t.Fatalf("log disclosed protected cause: %q", logBuffer.String())
	}
}

func TestPhase6Step8CompletionAndRescheduleErrorsDoNotDiscloseIdentifiers(t *testing.T) {
	secretID := "99999999-9999-9999-9999-999999999999"
	secretCause := errors.New("postgresql://user:secret@database/internal")
	store := &step8FailingIntegrationStore{completionErr: &database.Error{Stage: "completion", Cause: secretCause}, rescheduleErr: &database.Error{Stage: "reschedule", Cause: secretCause}}
	var logBuffer bytes.Buffer
	runner := &integrationRunner{
		store: store,
		client: relayClientFunc(func(context.Context, relayEnvelope) error {
			if store.deliveries.Add(1) == 1 {
				return nil
			}
			return &Error{Stage: "relay response", Code: "delivery_relay_unavailable", Cause: errors.New("relay secret")}
		}),
		cfg:    testDeliveryConfig("https://relay.example.test/v1/deliver"),
		logger: slog.New(slog.NewTextHandler(&logBuffer, nil)),
	}

	claim := database.IntegrationOutboxClaim{
		OutboxEventID:         secretID,
		IntegrationContractID: "contract-secret",
		Payload:               json.RawMessage(`{"secret":"payload"}`),
		AttemptNumber:         1,
	}
	runner.processOne(context.Background(), claim)
	runner.processOne(context.Background(), claim)

	logText := logBuffer.String()
	for _, forbidden := range []string{secretID, "contract-secret", "payload", "postgresql://", "relay secret", "user:secret"} {
		if contains(logText, forbidden) {
			t.Fatalf("log disclosed %q: %s", forbidden, logText)
		}
	}
}

type step8FailingIntegrationStore struct {
	deliveries    atomic.Int32
	completionErr error
	rescheduleErr error
}

func (*step8FailingIntegrationStore) ClaimIntegrationOutbox(context.Context, int32, time.Duration) ([]database.IntegrationOutboxClaim, error) {
	return nil, nil
}
func (store *step8FailingIntegrationStore) MarkIntegrationDelivered(context.Context, string) (bool, error) {
	return false, store.completionErr
}
func (store *step8FailingIntegrationStore) RescheduleIntegration(context.Context, string, string, time.Duration) (bool, error) {
	return false, store.rescheduleErr
}
