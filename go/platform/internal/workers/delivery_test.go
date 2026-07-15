package workers

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

func TestHTTPRelayClientUsesBoundedAuthenticatedEnvelope(t *testing.T) {
	t.Parallel()
	token := []byte("0123456789abcdef0123456789abcdef")
	requestSeen := make(chan struct{}, 1)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer r.Body.Close()
		body, err := io.ReadAll(io.LimitReader(r.Body, maximumEnvelopeBytes+1))
		if err != nil {
			t.Errorf("ReadAll() error = %v", err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		if r.Method != http.MethodPost || r.Header.Get("Idempotency-Key") != "delivery-1" {
			t.Errorf("unexpected request method or idempotency header")
		}
		if got := r.Header.Get("Authorization"); got != "Bearer "+base64.RawURLEncoding.EncodeToString(token) {
			t.Errorf("Authorization = %q", got)
		}
		var envelope relayEnvelope
		if err := json.Unmarshal(body, &envelope); err != nil {
			t.Errorf("json.Unmarshal() error = %v", err)
		}
		if envelope.Version != deliveryEnvelopeVersion || envelope.Kind != integrationKind || envelope.DeliveryID != "delivery-1" {
			t.Errorf("envelope = %#v", envelope)
		}
		requestSeen <- struct{}{}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	cfg := testDeliveryConfig(server.URL + "/relay")
	client, err := newHTTPRelayClient(database.IntegrationDeliveryWorker, cfg, token)
	if err != nil {
		t.Fatalf("newHTTPRelayClient() error = %v", err)
	}
	err = client.Deliver(context.Background(), relayEnvelope{
		Version:        deliveryEnvelopeVersion,
		Kind:           integrationKind,
		DeliveryID:     "delivery-1",
		AttemptNumber:  1,
		ClaimExpiresAt: time.Now().UTC().Add(time.Minute),
		Metadata:       json.RawMessage(`{"contract_key":"test"}`),
		Payload:        json.RawMessage(`{"event":"test"}`),
	})
	if err != nil {
		t.Fatalf("Deliver() error = %v diagnostic=%s", err, Diagnostic(err))
	}
	select {
	case <-requestSeen:
	case <-time.After(time.Second):
		t.Fatal("relay did not receive request")
	}
}

func TestHTTPRelayClientClassifiesFailuresWithoutResponseDisclosure(t *testing.T) {
	t.Parallel()
	token := []byte("0123456789abcdef0123456789abcdef")
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
		_, _ = w.Write([]byte("secret upstream response"))
	}))
	defer server.Close()
	client, err := newHTTPRelayClient(database.MonitoringDeliveryWorker, testDeliveryConfig(server.URL+"/relay"), token)
	if err != nil {
		t.Fatalf("newHTTPRelayClient() error = %v", err)
	}
	err = client.Deliver(context.Background(), relayEnvelope{Version: deliveryEnvelopeVersion, Kind: monitoringKind, DeliveryID: "delivery-2", AttemptNumber: 1, ClaimExpiresAt: time.Now().UTC().Add(time.Minute), Metadata: json.RawMessage(`{}`), Payload: json.RawMessage(`{}`)})
	if got := Diagnostic(err); got != "delivery_relay_unavailable" {
		t.Fatalf("Diagnostic() = %q, want delivery_relay_unavailable", got)
	}
	if err != nil && contains(err.Error(), "secret upstream response") {
		t.Fatalf("error disclosed response: %q", err)
	}
}

func TestRetryDelayIsExponentialAndBounded(t *testing.T) {
	t.Parallel()
	cases := []struct {
		attempt int32
		want    time.Duration
	}{{0, time.Second}, {1, time.Second}, {2, 2 * time.Second}, {3, 4 * time.Second}, {4, 5 * time.Second}, {100, 5 * time.Second}}
	for _, testCase := range cases {
		if got := retryDelay(time.Second, 5*time.Second, testCase.attempt); got != testCase.want {
			t.Fatalf("retryDelay(attempt=%d) = %s, want %s", testCase.attempt, got, testCase.want)
		}
	}
}

func TestIntegrationRunnerMarksSuccessAndReschedulesFailure(t *testing.T) {
	t.Parallel()
	store := &fakeIntegrationStore{}
	client := &sequenceClient{errors: []error{nil, &Error{Code: "delivery_network_error"}}}
	cfg := testDeliveryConfig("https://relay.example.test/v1/deliver")
	cfg.MaxConcurrent = 1
	runner := &integrationRunner{store: store, client: client, cfg: cfg, logger: discardLogger()}
	claims := []database.IntegrationOutboxClaim{
		{OutboxEventID: "00000000-0000-0000-0000-000000000001", IntegrationContractID: "10000000-0000-0000-0000-000000000001", ContractKey: "contract-a", ExternalSystemName: "external", AdapterName: "adapter", AdapterVersion: "1", EventType: "event", AggregateType: "record", AggregateID: "1", Payload: json.RawMessage(`{"value":1}`), AttemptNumber: 1, ClaimExpiresAt: time.Now().UTC().Add(time.Minute)},
		{OutboxEventID: "00000000-0000-0000-0000-000000000002", IntegrationContractID: "10000000-0000-0000-0000-000000000001", ContractKey: "contract-a", ExternalSystemName: "external", AdapterName: "adapter", AdapterVersion: "1", EventType: "event", AggregateType: "record", AggregateID: "2", Payload: json.RawMessage(`{"value":2}`), AttemptNumber: 2, ClaimExpiresAt: time.Now().UTC().Add(time.Minute)},
	}
	runner.processBatch(context.Background(), claims)
	if store.marked != 1 || store.rescheduled != 1 || store.lastCode != "delivery_network_error" || store.lastDelay != 2*time.Second {
		t.Fatalf("store = %#v", store)
	}
}

func TestCanceledDeliveryLeavesClaimForLeaseRecovery(t *testing.T) {
	t.Parallel()
	store := &fakeIntegrationStore{}
	client := relayClientFunc(func(ctx context.Context, _ relayEnvelope) error {
		<-ctx.Done()
		return ctx.Err()
	})
	runner := &integrationRunner{store: store, client: client, cfg: testDeliveryConfig("https://relay.example.test/v1/deliver"), logger: discardLogger()}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	runner.processOne(ctx, database.IntegrationOutboxClaim{OutboxEventID: "id", IntegrationContractID: "contract", Payload: json.RawMessage(`{}`), AttemptNumber: 1})
	if store.marked != 0 || store.rescheduled != 0 {
		t.Fatalf("canceled claim was mutated: %#v", store)
	}
}

func TestBatchConcurrencyIsBounded(t *testing.T) {
	t.Parallel()
	var active atomic.Int32
	var maximum atomic.Int32
	release := make(chan struct{})
	client := relayClientFunc(func(context.Context, relayEnvelope) error {
		current := active.Add(1)
		for {
			observed := maximum.Load()
			if current <= observed || maximum.CompareAndSwap(observed, current) {
				break
			}
		}
		<-release
		active.Add(-1)
		return nil
	})
	store := &fakeIntegrationStore{}
	cfg := testDeliveryConfig("https://relay.example.test/v1/deliver")
	cfg.MaxConcurrent = 2
	runner := &integrationRunner{store: store, client: client, cfg: cfg, logger: discardLogger()}
	claims := make([]database.IntegrationOutboxClaim, 4)
	for index := range claims {
		claims[index] = database.IntegrationOutboxClaim{OutboxEventID: "id", IntegrationContractID: "contract", Payload: json.RawMessage(`{}`), AttemptNumber: 1}
	}
	done := make(chan struct{})
	go func() { runner.processBatch(context.Background(), claims); close(done) }()
	deadline := time.After(time.Second)
	for maximum.Load() < 2 {
		select {
		case <-deadline:
			t.Fatal("two concurrent deliveries were not observed")
		default:
			time.Sleep(time.Millisecond)
		}
	}
	close(release)
	<-done
	if maximum.Load() != 2 {
		t.Fatalf("maximum concurrency = %d, want 2", maximum.Load())
	}
}

func testDeliveryConfig(endpoint string) config.DeliveryWorker {
	return config.DeliveryWorker{Enabled: true, Endpoint: endpoint, BatchSize: 4, MaxConcurrent: 2, ClaimLease: 30 * time.Second, PollInterval: 10 * time.Millisecond, RequestTimeout: time.Second, RetryInitial: time.Second, RetryMaximum: 5 * time.Second}
}

func discardLogger() *slog.Logger { return slog.New(slog.NewTextHandler(io.Discard, nil)) }

type relayClientFunc func(context.Context, relayEnvelope) error

func (f relayClientFunc) Deliver(ctx context.Context, envelope relayEnvelope) error {
	return f(ctx, envelope)
}

type sequenceClient struct {
	mu     sync.Mutex
	errors []error
}

func (c *sequenceClient) Deliver(context.Context, relayEnvelope) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if len(c.errors) == 0 {
		return nil
	}
	err := c.errors[0]
	c.errors = c.errors[1:]
	return err
}

type fakeIntegrationStore struct {
	mu          sync.Mutex
	marked      int
	rescheduled int
	lastCode    string
	lastDelay   time.Duration
}

func (*fakeIntegrationStore) ClaimIntegrationOutbox(context.Context, int32, time.Duration) ([]database.IntegrationOutboxClaim, error) {
	return nil, nil
}
func (s *fakeIntegrationStore) MarkIntegrationDelivered(context.Context, string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.marked++
	return true, nil
}
func (s *fakeIntegrationStore) RescheduleIntegration(_ context.Context, _ string, code string, delay time.Duration) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.rescheduled++
	s.lastCode = code
	s.lastDelay = delay
	return true, nil
}

func contains(value, candidate string) bool {
	return len(candidate) > 0 && len(value) >= len(candidate) && func() bool {
		for i := 0; i+len(candidate) <= len(value); i++ {
			if value[i:i+len(candidate)] == candidate {
				return true
			}
		}
		return false
	}()
}

func TestValidateWorkerConfigRejectsUnboundedValues(t *testing.T) {
	t.Parallel()
	cfg := testDeliveryConfig("https://relay.example.test/v1/deliver")
	cfg.TokenFile = "/run/credentials/worker/delivery-token"
	cfg.PollInterval = 100 * time.Millisecond
	if err := validateWorkerConfig(cfg); err != nil {
		t.Fatalf("validateWorkerConfig() error = %v", err)
	}
	cfg.MaxConcurrent = cfg.BatchSize + 1
	if err := validateWorkerConfig(cfg); err == nil {
		t.Fatal("validateWorkerConfig() accepted concurrency above batch size")
	}
}

func TestHTTPRelayClientCloseZeroesCredential(t *testing.T) {
	t.Parallel()
	token := []byte("0123456789abcdef0123456789abcdef")
	client, err := newHTTPRelayClient(
		database.IntegrationDeliveryWorker,
		testDeliveryConfig("https://relay.example.test/v1/deliver"),
		token,
	)
	if err != nil {
		t.Fatalf("newHTTPRelayClient() error = %v", err)
	}
	retained := client.token
	client.Close()
	for index, value := range retained {
		if value != 0 {
			t.Fatalf("retained token byte %d was not zeroed", index)
		}
	}
	if client.token != nil {
		t.Fatal("client retained token slice after Close")
	}
	client.Close()
}

func TestRejectedIntegrationPayloadIsRescheduledWithoutNetworkDelivery(t *testing.T) {
	t.Parallel()
	store := &fakeIntegrationStore{}
	var deliveries atomic.Int32
	client := relayClientFunc(func(context.Context, relayEnvelope) error {
		deliveries.Add(1)
		return nil
	})
	runner := &integrationRunner{
		store:  store,
		client: client,
		cfg:    testDeliveryConfig("https://relay.example.test/v1/deliver"),
		logger: discardLogger(),
	}
	runner.processOne(context.Background(), database.IntegrationOutboxClaim{
		OutboxEventID:   "id",
		PayloadRejected: true,
		AttemptNumber:   1,
	})
	if deliveries.Load() != 0 {
		t.Fatalf("network deliveries = %d, want 0", deliveries.Load())
	}
	if store.rescheduled != 1 || store.lastCode != "delivery_payload_rejected" {
		t.Fatalf("store = %#v", store)
	}
}
