//go:build integration

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

func TestPhase6Step8HostileDeliveryRuntime(t *testing.T) {
	integrationDSN := requiredEnvironment(t, "ISSP_TEST_INTEGRATION_DSN_FILE")
	monitoringDSN := requiredEnvironment(t, "ISSP_TEST_MONITORING_DSN_FILE")
	integrationTokenFile := requiredEnvironment(t, "ISSP_TEST_INTEGRATION_TOKEN_FILE")
	monitoringTokenFile := requiredEnvironment(t, "ISSP_TEST_MONITORING_TOKEN_FILE")
	integrationToken, err := config.ReadDeliveryToken(integrationTokenFile)
	if err != nil {
		t.Fatalf("ReadDeliveryToken(integration) error = %v", err)
	}
	monitoringToken, err := config.ReadDeliveryToken(monitoringTokenFile)
	if err != nil {
		t.Fatalf("ReadDeliveryToken(monitoring) error = %v", err)
	}

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

	var mu sync.Mutex
	seen := make(map[string]int)
	relay := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer r.Body.Close()
		if r.Method != http.MethodPost || r.URL.Path != "/v1/deliveries" || r.URL.RawQuery != "" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		body, readErr := io.ReadAll(io.LimitReader(r.Body, maximumEnvelopeBytes+1))
		if readErr != nil || len(body) > maximumEnvelopeBytes {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		var envelope relayEnvelope
		if json.Unmarshal(body, &envelope) != nil || envelope.Version != deliveryEnvelopeVersion || envelope.DeliveryID == "" || envelope.DeliveryID != r.Header.Get("Idempotency-Key") {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		expectedToken := integrationToken
		if envelope.Kind == monitoringKind {
			expectedToken = monitoringToken
		}
		if r.Header.Get("Authorization") != "Bearer "+base64.RawURLEncoding.EncodeToString(expectedToken) {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		if r.Header.Get("X-ISSP-Delivery-Kind") != string(envelope.Kind) || r.Header.Get("X-ISSP-Delivery-Attempt") == "" {
			w.WriteHeader(http.StatusBadRequest)
			return
		}

		mu.Lock()
		seen[envelope.DeliveryID]++
		mu.Unlock()

		switch envelope.DeliveryID {
		case "81100000-0000-0000-0000-000000000001", "82300000-0000-0000-0000-000000000001":
			w.WriteHeader(http.StatusNoContent)
		case "81100000-0000-0000-0000-000000000002", "82300000-0000-0000-0000-000000000002":
			select {
			case <-r.Context().Done():
			case <-time.After(1200 * time.Millisecond):
			}
		case "81100000-0000-0000-0000-000000000003", "82300000-0000-0000-0000-000000000003":
			step8CloseConnection(w)
		case "81100000-0000-0000-0000-000000000004", "82300000-0000-0000-0000-000000000004":
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte("protected upstream unavailable detail"))
		case "81100000-0000-0000-0000-000000000005", "82300000-0000-0000-0000-000000000005":
			w.WriteHeader(http.StatusBadRequest)
			_, _ = w.Write([]byte("protected upstream rejection detail"))
		case "81100000-0000-0000-0000-000000000006", "82300000-0000-0000-0000-000000000006":
			http.Redirect(w, r, redirectTarget.URL+"/credential-capture", http.StatusTemporaryRedirect)
		case "81100000-0000-0000-0000-000000000007", "82300000-0000-0000-0000-000000000007":
			step8WriteMalformedResponse(w)
		case "81100000-0000-0000-0000-000000000008", "82300000-0000-0000-0000-000000000008":
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write(make([]byte, maximumResponseDrain*4))
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer relay.Close()

	workerCfg := config.DeliveryWorker{
		Enabled:            true,
		Endpoint:           relay.URL + "/v1/deliveries",
		AllowInsecureLocal: true,
		BatchSize:          8,
		MaxConcurrent:      4,
		ClaimLease:         30 * time.Second,
		PollInterval:       time.Second,
		RequestTimeout:     time.Second,
		RetryInitial:       2 * time.Second,
		RetryMaximum:       30 * time.Second,
	}

	integrationPool := openWorkerPool(t, integrationDSN, database.IntegrationDeliveryWorker)
	defer integrationPool.Close()
	monitoringPool := openWorkerPool(t, monitoringDSN, database.MonitoringDeliveryWorker)
	defer monitoringPool.Close()

	integrationClaims, err := integrationPool.ClaimIntegrationOutbox(context.Background(), 8, 30*time.Second)
	if err != nil || len(integrationClaims) != 8 {
		t.Fatalf("ClaimIntegrationOutbox() count=%d error=%v", len(integrationClaims), err)
	}
	monitoringClaims, err := monitoringPool.ClaimMonitoringDeliveries(context.Background(), 8, 30*time.Second)
	if err != nil || len(monitoringClaims) != 8 {
		t.Fatalf("ClaimMonitoringDeliveries() count=%d error=%v", len(monitoringClaims), err)
	}

	integrationClient, err := newHTTPRelayClient(database.IntegrationDeliveryWorker, workerCfg, integrationToken)
	if err != nil {
		t.Fatalf("newHTTPRelayClient(integration) error = %v", err)
	}
	defer integrationClient.Close()
	monitoringClient, err := newHTTPRelayClient(database.MonitoringDeliveryWorker, workerCfg, monitoringToken)
	if err != nil {
		t.Fatalf("newHTTPRelayClient(monitoring) error = %v", err)
	}
	defer monitoringClient.Close()

	integrationRunner := &integrationRunner{store: integrationPool, client: integrationClient, cfg: workerCfg, logger: slog.New(slog.NewTextHandler(io.Discard, nil))}
	monitoringRunner := &monitoringRunner{store: monitoringPool, client: monitoringClient, cfg: workerCfg, logger: slog.New(slog.NewTextHandler(io.Discard, nil))}
	var waitGroup sync.WaitGroup
	waitGroup.Add(2)
	go func() {
		defer waitGroup.Done()
		integrationRunner.processBatch(context.Background(), integrationClaims)
	}()
	go func() {
		defer waitGroup.Done()
		monitoringRunner.processBatch(context.Background(), monitoringClaims)
	}()
	waitGroup.Wait()

	mu.Lock()
	defer mu.Unlock()
	for _, prefix := range []string{"811", "823"} {
		for index := 1; index <= 8; index++ {
			id := prefix + "00000-0000-0000-0000-" + step8TwelveDigits(index)
			count := seen[id]

			if count == 0 {
				t.Fatalf(
					"relay count for %s = 0, want at least 1",
					id,
				)
			}

			// Immediate disconnect and malformed HTTP response are
			// ambiguous transport failures. Because the request has a
			// durable Idempotency-Key and a rewindable body, Go's HTTP
			// transport may replay it. The relay must deduplicate these
			// attempts using the unchanged durable delivery identifier.
			if index == 3 || index == 7 {
				continue
			}

			if count != 1 {
				t.Fatalf(
					"relay count for non-ambiguous outcome %s = %d, want 1",
					id,
					count,
				)
			}
		}
	}
	if proxyCalls.Load() != 0 {
		t.Fatalf("ambient proxy calls = %d, want 0", proxyCalls.Load())
	}
	if redirectCalls.Load() != 0 {
		t.Fatalf("redirect target calls = %d, want 0", redirectCalls.Load())
	}
}

func step8CloseConnection(w http.ResponseWriter) {
	hijacker, ok := w.(http.Hijacker)
	if !ok {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	connection, _, err := hijacker.Hijack()
	if err == nil {
		_ = connection.Close()
	}
}

func step8WriteMalformedResponse(w http.ResponseWriter) {
	hijacker, ok := w.(http.Hijacker)
	if !ok {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	connection, buffer, err := hijacker.Hijack()
	if err != nil {
		return
	}
	_, _ = buffer.WriteString("THIS IS NOT HTTP\r\n\r\n")
	_ = buffer.Flush()
	_ = connection.Close()
}

func step8TwelveDigits(value int) string {
	const digits = "000000000000"
	text := []byte(digits)
	for index := len(text) - 1; value > 0 && index >= 0; index-- {
		text[index] = byte('0' + value%10)
		value /= 10
	}
	return string(text)
}
