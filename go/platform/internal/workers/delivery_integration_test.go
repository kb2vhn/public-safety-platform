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
	"os"
	"sort"
	"sync"
	"testing"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

func TestIntegrationDeliveryWorkers(t *testing.T) {
	integrationDSN := requiredEnvironment(t, "ISSP_TEST_INTEGRATION_DSN_FILE")
	monitoringDSN := requiredEnvironment(t, "ISSP_TEST_MONITORING_DSN_FILE")
	tokenFile := requiredEnvironment(t, "ISSP_TEST_DELIVERY_TOKEN_FILE")
	token, err := config.ReadDeliveryToken(tokenFile)
	if err != nil {
		t.Fatalf("ReadDeliveryToken() error = %v", err)
	}

	var mu sync.Mutex
	seen := make(map[string]int)
	relay := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer r.Body.Close()
		body, readErr := io.ReadAll(io.LimitReader(r.Body, maximumEnvelopeBytes+1))
		if readErr != nil || len(body) > maximumEnvelopeBytes {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		if r.Header.Get("Authorization") != "Bearer "+base64.RawURLEncoding.EncodeToString(token) || r.Header.Get("Idempotency-Key") == "" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		var envelope relayEnvelope
		if json.Unmarshal(body, &envelope) != nil || envelope.Version != deliveryEnvelopeVersion || envelope.DeliveryID != r.Header.Get("Idempotency-Key") {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		mu.Lock()
		seen[envelope.DeliveryID]++
		mu.Unlock()
		switch envelope.DeliveryID {
		case "71100000-0000-0000-0000-000000000004", "72300000-0000-0000-0000-000000000002", "72300000-0000-0000-0000-000000000003":
			w.WriteHeader(http.StatusServiceUnavailable)
		default:
			w.WriteHeader(http.StatusNoContent)
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
		RequestTimeout:     2 * time.Second,
		RetryInitial:       2 * time.Second,
		RetryMaximum:       30 * time.Second,
	}

	integrationPool := openWorkerPool(t, integrationDSN, database.IntegrationDeliveryWorker)
	defer integrationPool.Close()
	secondIntegrationPool := openWorkerPool(t, integrationDSN, database.IntegrationDeliveryWorker)
	defer secondIntegrationPool.Close()
	monitoringPool := openWorkerPool(t, monitoringDSN, database.MonitoringDeliveryWorker)
	defer monitoringPool.Close()

	start := make(chan struct{})
	claimResults := make(chan database.IntegrationOutboxClaim, 2)
	claimErrors := make(chan error, 2)
	for _, pool := range []*database.Pool{integrationPool, secondIntegrationPool} {
		pool := pool
		go func() {
			<-start
			claims, claimErr := pool.ClaimIntegrationOutbox(context.Background(), 1, 30*time.Second)
			if claimErr != nil {
				claimErrors <- claimErr
				return
			}
			if len(claims) != 1 {
				claimErrors <- &Error{Stage: "concurrent claim", Code: "delivery_claim_count_invalid"}
				return
			}
			claimResults <- claims[0]
		}()
	}
	close(start)
	var concurrentClaims []database.IntegrationOutboxClaim
	for range 2 {
		select {
		case claimErr := <-claimErrors:
			t.Fatalf("concurrent claim error = %v diagnostic=%s", claimErr, Diagnostic(claimErr))
		case claim := <-claimResults:
			concurrentClaims = append(concurrentClaims, claim)
		case <-time.After(5 * time.Second):
			t.Fatal("concurrent claim timed out")
		}
	}
	sort.Slice(concurrentClaims, func(i, j int) bool { return concurrentClaims[i].OutboxEventID < concurrentClaims[j].OutboxEventID })
	if concurrentClaims[0].OutboxEventID == concurrentClaims[1].OutboxEventID {
		t.Fatalf("duplicate concurrent claim: %#v", concurrentClaims)
	}
	for _, claim := range concurrentClaims {
		updated, markErr := integrationPool.MarkIntegrationDelivered(context.Background(), claim.OutboxEventID)
		if markErr != nil || !updated {
			t.Fatalf("MarkIntegrationDelivered() updated=%v error=%v", updated, markErr)
		}
	}

	integrationClaims, err := integrationPool.ClaimIntegrationOutbox(context.Background(), 8, 30*time.Second)
	if err != nil || len(integrationClaims) != 2 {
		t.Fatalf("ClaimIntegrationOutbox() count=%d error=%v", len(integrationClaims), err)
	}
	integrationClient, err := newHTTPRelayClient(database.IntegrationDeliveryWorker, workerCfg, token)
	if err != nil {
		t.Fatalf("newHTTPRelayClient(integration) error = %v", err)
	}
	integration := &integrationRunner{store: integrationPool, client: integrationClient, cfg: workerCfg, logger: slog.New(slog.NewTextHandler(io.Discard, nil))}
	integration.processBatch(context.Background(), integrationClaims)

	monitoringClaims, err := monitoringPool.ClaimMonitoringDeliveries(context.Background(), 8, 30*time.Second)
	if err != nil || len(monitoringClaims) != 3 {
		t.Fatalf("ClaimMonitoringDeliveries() count=%d error=%v", len(monitoringClaims), err)
	}
	monitoringClient, err := newHTTPRelayClient(database.MonitoringDeliveryWorker, workerCfg, token)
	if err != nil {
		t.Fatalf("newHTTPRelayClient(monitoring) error = %v", err)
	}
	monitoring := &monitoringRunner{store: monitoringPool, client: monitoringClient, cfg: workerCfg, logger: slog.New(slog.NewTextHandler(io.Discard, nil))}
	monitoring.processBatch(context.Background(), monitoringClaims)

	mu.Lock()
	defer mu.Unlock()
	for _, id := range []string{
		"71100000-0000-0000-0000-000000000003",
		"71100000-0000-0000-0000-000000000004",
		"72300000-0000-0000-0000-000000000001",
		"72300000-0000-0000-0000-000000000002",
		"72300000-0000-0000-0000-000000000003",
	} {
		if seen[id] != 1 {
			t.Fatalf("relay count for %s = %d, want 1", id, seen[id])
		}
	}
}

func openWorkerPool(t *testing.T, dsnFile string, identity database.ServiceIdentity) *database.Pool {
	t.Helper()
	cfg := config.Config{
		ProcessName:     identity.ProcessName,
		StartupTimeout:  10 * time.Second,
		ShutdownTimeout: 5 * time.Second,
		Database: config.Database{
			DSNFile:               dsnFile,
			AllowInsecureLocal:    true,
			ConnectTimeout:        5 * time.Second,
			MaxConnections:        4,
			MinConnections:        0,
			MaxConnectionLifetime: 5 * time.Minute,
			MaxConnectionIdleTime: time.Minute,
			HealthCheckPeriod:     10 * time.Second,
		},
	}
	ctx, cancel := context.WithTimeout(context.Background(), cfg.StartupTimeout)
	defer cancel()
	pool, report, err := database.Open(ctx, cfg, identity)
	if err != nil {
		t.Fatalf("database.Open(%s) error = %v diagnostic=%s", identity.ProcessName, err, database.Diagnostic(err))
	}
	if report.CurrentUser != identity.PostgreSQLRole {
		pool.Close()
		t.Fatalf("CurrentUser = %q, want %q", report.CurrentUser, identity.PostgreSQLRole)
	}
	return pool
}

func requiredEnvironment(t *testing.T, name string) string {
	t.Helper()
	value := os.Getenv(name)
	if value == "" {
		t.Fatalf("required integration environment missing: %s", name)
	}
	return value
}
