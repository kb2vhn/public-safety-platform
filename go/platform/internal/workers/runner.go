package workers

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/config"
	"github.com/Iron-Signal-Systems/iron-signal-platform/go/platform/internal/database"
)

type integrationStore interface {
	ClaimIntegrationOutbox(context.Context, int32, time.Duration) ([]database.IntegrationOutboxClaim, error)
	MarkIntegrationDelivered(context.Context, string) (bool, error)
	RescheduleIntegration(context.Context, string, string, time.Duration) (bool, error)
}

type monitoringStore interface {
	ClaimMonitoringDeliveries(context.Context, int32, time.Duration) ([]database.MonitoringDeliveryClaim, error)
	MarkMonitoringDelivered(context.Context, string) (bool, error)
	RescheduleMonitoring(context.Context, string, string, time.Duration) (string, error)
}

type integrationRunner struct {
	store  integrationStore
	client relayClient
	cfg    config.DeliveryWorker
	logger *slog.Logger
}

type monitoringRunner struct {
	store  monitoringStore
	client relayClient
	cfg    config.DeliveryWorker
	logger *slog.Logger
}

// New constructs exactly one of the two accepted delivery workers.
func New(pool *database.Pool, cfg config.DeliveryWorker, token []byte, logger *slog.Logger) (Runner, error) {
	if pool == nil || logger == nil {
		return nil, &Error{Stage: "worker construction", Code: "delivery_configuration_rejected", Cause: errors.New("worker prerequisites are missing")}
	}
	if err := validateWorkerConfig(cfg); err != nil {
		return nil, err
	}
	client, err := newHTTPRelayClient(pool.Identity(), cfg, token)
	if err != nil {
		return nil, err
	}
	switch pool.Identity() {
	case database.IntegrationDeliveryWorker:
		return &integrationRunner{store: pool, client: client, cfg: cfg, logger: logger}, nil
	case database.MonitoringDeliveryWorker:
		return &monitoringRunner{store: pool, client: client, cfg: cfg, logger: logger}, nil
	default:
		return nil, &Error{Stage: "worker construction", Code: "delivery_identity_rejected", Cause: errors.New("identity cannot run a delivery worker")}
	}
}

func validateWorkerConfig(cfg config.DeliveryWorker) error {
	if !cfg.Enabled || strings.TrimSpace(cfg.Endpoint) == "" || strings.TrimSpace(cfg.TokenFile) == "" {
		return &Error{Stage: "worker construction", Code: "delivery_configuration_rejected", Cause: errors.New("required worker configuration is missing")}
	}
	if cfg.BatchSize < 1 || cfg.BatchSize > 32 || cfg.MaxConcurrent < 1 || cfg.MaxConcurrent > 16 || cfg.MaxConcurrent > cfg.BatchSize {
		return &Error{Stage: "worker construction", Code: "delivery_configuration_rejected", Cause: errors.New("worker batch or concurrency is outside the accepted boundary")}
	}
	if cfg.ClaimLease < 10*time.Second || cfg.ClaimLease > 5*time.Minute || cfg.RequestTimeout < time.Second || cfg.RequestTimeout > 30*time.Second || cfg.RequestTimeout >= cfg.ClaimLease {
		return &Error{Stage: "worker construction", Code: "delivery_configuration_rejected", Cause: errors.New("worker lease or request timeout is outside the accepted boundary")}
	}
	if cfg.PollInterval < 100*time.Millisecond || cfg.PollInterval > 30*time.Second || cfg.RetryInitial < time.Second || cfg.RetryInitial > 5*time.Minute || cfg.RetryMaximum < cfg.RetryInitial || cfg.RetryMaximum > 24*time.Hour {
		return &Error{Stage: "worker construction", Code: "delivery_configuration_rejected", Cause: errors.New("worker polling or retry configuration is outside the accepted boundary")}
	}
	return nil
}

func (r *integrationRunner) Close() { closeRelayClient(r.client) }
func (r *monitoringRunner) Close()  { closeRelayClient(r.client) }

func closeRelayClient(client relayClient) {
	if closer, ok := client.(interface{ Close() }); ok {
		closer.Close()
	}
}

func (r *integrationRunner) Run(ctx context.Context) error {
	return runLoop(ctx, r.cfg.PollInterval, func(cycleContext context.Context) error {
		claimContext, cancel := context.WithTimeout(cycleContext, databaseOperationTimeout)
		claims, err := r.store.ClaimIntegrationOutbox(claimContext, r.cfg.BatchSize, r.cfg.ClaimLease)
		cancel()
		if err != nil {
			return err
		}
		r.processBatch(cycleContext, claims)
		return nil
	}, r.logger, "integration")
}

func (r *monitoringRunner) Run(ctx context.Context) error {
	return runLoop(ctx, r.cfg.PollInterval, func(cycleContext context.Context) error {
		claimContext, cancel := context.WithTimeout(cycleContext, databaseOperationTimeout)
		claims, err := r.store.ClaimMonitoringDeliveries(claimContext, r.cfg.BatchSize, r.cfg.ClaimLease)
		cancel()
		if err != nil {
			return err
		}
		r.processBatch(cycleContext, claims)
		return nil
	}, r.logger, "monitoring")
}

func runLoop(ctx context.Context, pollInterval time.Duration, cycle func(context.Context) error, logger *slog.Logger, kind string) error {
	for {
		if ctx.Err() != nil {
			return nil
		}
		if err := cycle(ctx); err != nil && ctx.Err() == nil {
			logger.Error("delivery claim failed", "worker_kind", kind, "diagnostic", Diagnostic(err))
		}
		timer := time.NewTimer(pollInterval)
		select {
		case <-ctx.Done():
			if !timer.Stop() {
				<-timer.C
			}
			return nil
		case <-timer.C:
		}
	}
}

func (r *integrationRunner) processBatch(ctx context.Context, claims []database.IntegrationOutboxClaim) {
	semaphore := make(chan struct{}, r.cfg.MaxConcurrent)
	var waitGroup sync.WaitGroup
	for _, claim := range claims {
		if ctx.Err() != nil {
			break
		}
		claim := claim
		semaphore <- struct{}{}
		waitGroup.Add(1)
		go func() {
			defer waitGroup.Done()
			defer func() { <-semaphore }()
			r.processOne(ctx, claim)
		}()
	}
	waitGroup.Wait()
}

func (r *monitoringRunner) processBatch(ctx context.Context, claims []database.MonitoringDeliveryClaim) {
	semaphore := make(chan struct{}, r.cfg.MaxConcurrent)
	var waitGroup sync.WaitGroup
	for _, claim := range claims {
		if ctx.Err() != nil {
			break
		}
		claim := claim
		semaphore <- struct{}{}
		waitGroup.Add(1)
		go func() {
			defer waitGroup.Done()
			defer func() { <-semaphore }()
			r.processOne(ctx, claim)
		}()
	}
	waitGroup.Wait()
}

func (r *integrationRunner) processOne(ctx context.Context, claim database.IntegrationOutboxClaim) {
	var err error
	if claim.PayloadRejected {
		err = &Error{Stage: "payload validation", Code: "delivery_payload_rejected", Cause: errors.New("claimed payload is outside the accepted boundary")}
	}
	metadata, metadataErr := compactMetadata(struct {
		IntegrationContractID   string    `json:"integration_contract_id"`
		ContractKey             string    `json:"contract_key"`
		ExternalSystemName      string    `json:"external_system_name"`
		AdapterName             string    `json:"adapter_name"`
		AdapterVersion          string    `json:"adapter_version"`
		EventType               string    `json:"event_type"`
		AggregateType           string    `json:"aggregate_type"`
		AggregateID             string    `json:"aggregate_id"`
		ClassificationReference string    `json:"classification_reference,omitempty"`
		CreatedAt               time.Time `json:"created_at"`
	}{claim.IntegrationContractID, claim.ContractKey, claim.ExternalSystemName, claim.AdapterName, claim.AdapterVersion, claim.EventType, claim.AggregateType, claim.AggregateID, claim.ClassificationReference, claim.CreatedAt})
	if err == nil {
		err = metadataErr
	}
	if err == nil {
		err = r.client.Deliver(ctx, relayEnvelope{deliveryEnvelopeVersion, integrationKind, claim.OutboxEventID, claim.AttemptNumber, claim.ClaimExpiresAt, metadata, claim.Payload})
	}
	if err == nil {
		completionContext, cancel := context.WithTimeout(context.Background(), databaseOperationTimeout)
		updated, completeErr := r.store.MarkIntegrationDelivered(completionContext, claim.OutboxEventID)
		cancel()
		if completeErr != nil {
			r.logger.Error("delivery completion failed", "worker_kind", "integration", "diagnostic", Diagnostic(completeErr))
		} else if !updated {
			r.logger.Info("delivery completion was stale", "worker_kind", "integration")
		}
		return
	}
	if ctx.Err() != nil {
		return
	}
	r.reschedule(claim, Diagnostic(err))
}

func (r *integrationRunner) reschedule(claim database.IntegrationOutboxClaim, code string) {
	delay := retryDelay(r.cfg.RetryInitial, r.cfg.RetryMaximum, claim.AttemptNumber)
	rescheduleContext, cancel := context.WithTimeout(context.Background(), databaseOperationTimeout)
	updated, err := r.store.RescheduleIntegration(rescheduleContext, claim.OutboxEventID, code, delay)
	cancel()
	if err != nil {
		r.logger.Error("delivery reschedule failed", "worker_kind", "integration", "diagnostic", Diagnostic(err))
	} else if !updated {
		r.logger.Info("delivery reschedule was stale", "worker_kind", "integration")
	}
}

func (r *monitoringRunner) processOne(ctx context.Context, claim database.MonitoringDeliveryClaim) {
	var err error
	if claim.PayloadRejected {
		err = &Error{Stage: "payload validation", Code: "delivery_payload_rejected", Cause: errors.New("claimed payload is outside the accepted boundary")}
	} else if claim.EventFilterRejected {
		err = &Error{Stage: "metadata validation", Code: "delivery_metadata_rejected", Cause: errors.New("claimed metadata is outside the accepted boundary")}
	}
	metadata, metadataErr := compactMetadata(struct {
		MonitoringSubscriptionID string          `json:"monitoring_subscription_id"`
		SubscriptionKey          string          `json:"subscription_key"`
		DestinationType          string          `json:"destination_type"`
		DestinationReference     string          `json:"destination_reference"`
		EventFilter              json.RawMessage `json:"event_filter"`
		HealthEventID            string          `json:"health_event_id,omitempty"`
		MetricSampleID           int64           `json:"metric_sample_id,omitempty"`
	}{claim.MonitoringSubscriptionID, claim.SubscriptionKey, claim.DestinationType, claim.DestinationReference, claim.EventFilter, claim.HealthEventID, claim.MetricSampleID})
	if err == nil {
		err = metadataErr
	}
	payload := claim.HealthEvent
	if claim.MetricSampleID != 0 {
		payload = claim.MetricSample
	}
	if err == nil {
		err = r.client.Deliver(ctx, relayEnvelope{deliveryEnvelopeVersion, monitoringKind, claim.MonitoringDeliveryStateID, claim.AttemptNumber, claim.ClaimExpiresAt, metadata, payload})
	}
	if err == nil {
		completionContext, cancel := context.WithTimeout(context.Background(), databaseOperationTimeout)
		updated, completeErr := r.store.MarkMonitoringDelivered(completionContext, claim.MonitoringDeliveryStateID)
		cancel()
		if completeErr != nil {
			r.logger.Error("delivery completion failed", "worker_kind", "monitoring", "diagnostic", Diagnostic(completeErr))
		} else if !updated {
			r.logger.Info("delivery completion was stale", "worker_kind", "monitoring")
		}
		return
	}
	if ctx.Err() != nil {
		return
	}
	r.reschedule(claim, Diagnostic(err))
}

func (r *monitoringRunner) reschedule(claim database.MonitoringDeliveryClaim, code string) {
	delay := retryDelay(r.cfg.RetryInitial, r.cfg.RetryMaximum, claim.AttemptNumber)
	rescheduleContext, cancel := context.WithTimeout(context.Background(), databaseOperationTimeout)
	status, err := r.store.RescheduleMonitoring(rescheduleContext, claim.MonitoringDeliveryStateID, code, delay)
	cancel()
	if err != nil {
		r.logger.Error("delivery reschedule failed", "worker_kind", "monitoring", "diagnostic", Diagnostic(err))
		return
	}
	switch status {
	case "FAILED":
		r.logger.Error("monitoring retry budget exhausted", "worker_kind", "monitoring", "diagnostic", code)
	case "NOT_FOUND":
		r.logger.Info("delivery reschedule was stale", "worker_kind", "monitoring")
	}
}
