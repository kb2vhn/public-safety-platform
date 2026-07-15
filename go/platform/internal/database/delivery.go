package database

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

const maximumClaimedPayloadBytes = 256 * 1024

// IntegrationOutboxClaim is one atomically claimed integration delivery. All
// destination metadata is descriptive only; workers send to a deployment-owned
// relay endpoint and never interpret database values as network addresses.
type IntegrationOutboxClaim struct {
	OutboxEventID           string
	IntegrationContractID   string
	ContractKey             string
	ExternalSystemName      string
	AdapterName             string
	AdapterVersion          string
	EventType               string
	AggregateType           string
	AggregateID             string
	Payload                 json.RawMessage
	PayloadRejected         bool
	ClassificationReference string
	CreatedAt               time.Time
	AttemptNumber           int32
	ClaimExpiresAt          time.Time
}

// MonitoringDeliveryClaim is one atomically claimed monitoring delivery.
type MonitoringDeliveryClaim struct {
	MonitoringDeliveryStateID string
	MonitoringSubscriptionID  string
	SubscriptionKey           string
	DestinationType           string
	DestinationReference      string
	EventFilter               json.RawMessage
	EventFilterRejected       bool
	HealthEventID             string
	MetricSampleID            int64
	HealthEvent               json.RawMessage
	MetricSample              json.RawMessage
	PayloadRejected           bool
	AttemptNumber             int32
	ClaimExpiresAt            time.Time
}

// ClaimIntegrationOutbox invokes only the accepted integration claim routine.
func (p *Pool) ClaimIntegrationOutbox(ctx context.Context, limit int32, lease time.Duration) ([]IntegrationOutboxClaim, error) {
	const statement = `
SELECT
    outbox_event_id::text,
    integration_contract_id::text,
    contract_key,
    external_system_name,
    adapter_name,
    adapter_version,
    event_type,
    aggregate_type,
    aggregate_id,
    left(payload::text, 262145),
    COALESCE(classification_reference, ''),
    created_at,
    attempt_number,
    claim_expires_at
FROM integration.claim_outbox_events(
    $1::integer,
    ($2::bigint * interval '1 microsecond')
)`
	if err := p.validateDeliveryCall(ctx, IntegrationDeliveryWorker, limit, lease, "integration claim"); err != nil {
		return nil, err
	}
	rows, err := p.inner.Query(ctx, statement, limit, lease.Microseconds())
	if err != nil {
		return nil, &Error{Stage: "integration claim", Cause: err}
	}
	defer rows.Close()

	claims := make([]IntegrationOutboxClaim, 0, limit)
	for rows.Next() {
		var claim IntegrationOutboxClaim
		var payloadText string
		if err := rows.Scan(
			&claim.OutboxEventID,
			&claim.IntegrationContractID,
			&claim.ContractKey,
			&claim.ExternalSystemName,
			&claim.AdapterName,
			&claim.AdapterVersion,
			&claim.EventType,
			&claim.AggregateType,
			&claim.AggregateID,
			&payloadText,
			&claim.ClassificationReference,
			&claim.CreatedAt,
			&claim.AttemptNumber,
			&claim.ClaimExpiresAt,
		); err != nil {
			return nil, &Error{Stage: "integration claim scan", Cause: err}
		}
		claim.Payload, claim.PayloadRejected = boundedJSON(payloadText, maximumClaimedPayloadBytes)
		claims = append(claims, claim)
	}
	if err := rows.Err(); err != nil {
		return nil, &Error{Stage: "integration claim rows", Cause: err}
	}
	return claims, nil
}

// MarkIntegrationDelivered invokes only the accepted completion routine.
func (p *Pool) MarkIntegrationDelivered(ctx context.Context, eventID string) (bool, error) {
	const statement = "SELECT integration.mark_outbox_event_delivered($1::uuid)"
	if err := p.validateDeliveryIdentifier(ctx, IntegrationDeliveryWorker, eventID, "integration completion"); err != nil {
		return false, err
	}
	var updated bool
	if err := p.inner.QueryRow(ctx, statement, eventID).Scan(&updated); err != nil {
		return false, &Error{Stage: "integration completion", Cause: err}
	}
	return updated, nil
}

// RescheduleIntegration invokes only the accepted retry routine. PostgreSQL
// statement time constructs the future timestamp so host clock skew cannot
// accidentally make the requested retry time non-future.
func (p *Pool) RescheduleIntegration(ctx context.Context, eventID, errorCode string, delay time.Duration) (bool, error) {
	const statement = `SELECT integration.reschedule_outbox_event(
    $1::uuid,
    $2::text,
    statement_timestamp() + ($3::bigint * interval '1 microsecond')
)`
	if err := p.validateDeliveryMutation(ctx, IntegrationDeliveryWorker, eventID, errorCode, delay, "integration reschedule"); err != nil {
		return false, err
	}
	var updated bool
	if err := p.inner.QueryRow(ctx, statement, eventID, errorCode, delay.Microseconds()).Scan(&updated); err != nil {
		return false, &Error{Stage: "integration reschedule", Cause: err}
	}
	return updated, nil
}

// ClaimMonitoringDeliveries invokes only the accepted monitoring claim routine.
func (p *Pool) ClaimMonitoringDeliveries(ctx context.Context, limit int32, lease time.Duration) ([]MonitoringDeliveryClaim, error) {
	const statement = `
SELECT
    monitoring_delivery_state_id::text,
    monitoring_subscription_id::text,
    subscription_key,
    destination_type,
    destination_reference,
    left(event_filter::text, 32769),
    COALESCE(health_event_id::text, ''),
    COALESCE(metric_sample_id, 0),
    left(COALESCE(health_event::text, 'null'), 262145),
    left(COALESCE(metric_sample::text, 'null'), 262145),
    attempt_number,
    claim_expires_at
FROM observability.claim_monitoring_deliveries(
    $1::integer,
    ($2::bigint * interval '1 microsecond')
)`
	if err := p.validateDeliveryCall(ctx, MonitoringDeliveryWorker, limit, lease, "monitoring claim"); err != nil {
		return nil, err
	}
	rows, err := p.inner.Query(ctx, statement, limit, lease.Microseconds())
	if err != nil {
		return nil, &Error{Stage: "monitoring claim", Cause: err}
	}
	defer rows.Close()

	claims := make([]MonitoringDeliveryClaim, 0, limit)
	for rows.Next() {
		var claim MonitoringDeliveryClaim
		var eventFilterText, healthText, metricText string
		if err := rows.Scan(
			&claim.MonitoringDeliveryStateID,
			&claim.MonitoringSubscriptionID,
			&claim.SubscriptionKey,
			&claim.DestinationType,
			&claim.DestinationReference,
			&eventFilterText,
			&claim.HealthEventID,
			&claim.MetricSampleID,
			&healthText,
			&metricText,
			&claim.AttemptNumber,
			&claim.ClaimExpiresAt,
		); err != nil {
			return nil, &Error{Stage: "monitoring claim scan", Cause: err}
		}
		claim.EventFilter, claim.EventFilterRejected = boundedJSON(eventFilterText, 32*1024)
		healthPayload, healthRejected := boundedJSON(healthText, maximumClaimedPayloadBytes)
		metricPayload, metricRejected := boundedJSON(metricText, maximumClaimedPayloadBytes)
		claim.HealthEvent = healthPayload
		claim.MetricSample = metricPayload
		claim.PayloadRejected = healthRejected || metricRejected
		claims = append(claims, claim)
	}
	if err := rows.Err(); err != nil {
		return nil, &Error{Stage: "monitoring claim rows", Cause: err}
	}
	return claims, nil
}

// MarkMonitoringDelivered invokes only the accepted completion routine.
func (p *Pool) MarkMonitoringDelivered(ctx context.Context, stateID string) (bool, error) {
	const statement = "SELECT observability.mark_monitoring_delivery_delivered($1::uuid)"
	if err := p.validateDeliveryIdentifier(ctx, MonitoringDeliveryWorker, stateID, "monitoring completion"); err != nil {
		return false, err
	}
	var updated bool
	if err := p.inner.QueryRow(ctx, statement, stateID).Scan(&updated); err != nil {
		return false, &Error{Stage: "monitoring completion", Cause: err}
	}
	return updated, nil
}

// RescheduleMonitoring invokes only the accepted monitoring retry routine and
// returns RETRY, FAILED, or NOT_FOUND.
func (p *Pool) RescheduleMonitoring(ctx context.Context, stateID, errorCode string, delay time.Duration) (string, error) {
	const statement = `SELECT COALESCE(observability.reschedule_monitoring_delivery(
    $1::uuid,
    $2::text,
    statement_timestamp() + ($3::bigint * interval '1 microsecond')
), 'NOT_FOUND')`
	if err := p.validateDeliveryMutation(ctx, MonitoringDeliveryWorker, stateID, errorCode, delay, "monitoring reschedule"); err != nil {
		return "", err
	}
	var status string
	if err := p.inner.QueryRow(ctx, statement, stateID, errorCode, delay.Microseconds()).Scan(&status); err != nil {
		return "", &Error{Stage: "monitoring reschedule", Cause: err}
	}
	switch status {
	case "RETRY", "FAILED", "NOT_FOUND":
		return status, nil
	default:
		return "", &Error{Stage: "monitoring reschedule contract", Cause: fmt.Errorf("unexpected status")}
	}
}

func (p *Pool) validateDeliveryCall(ctx context.Context, identity ServiceIdentity, limit int32, lease time.Duration, stage string) error {
	if p == nil || p.inner == nil {
		return &Error{Stage: stage, Cause: fmt.Errorf("database pool is unavailable")}
	}
	if ctx == nil {
		return &Error{Stage: stage, Cause: fmt.Errorf("context is required")}
	}
	if p.identity != identity {
		return &Error{Stage: stage, Cause: fmt.Errorf("database identity is not authorized")}
	}
	if limit < 1 || limit > 32 {
		return &Error{Stage: stage, Cause: fmt.Errorf("claim limit is outside the worker boundary")}
	}
	if lease < 10*time.Second || lease > 5*time.Minute {
		return &Error{Stage: stage, Cause: fmt.Errorf("claim lease is outside the worker boundary")}
	}
	return nil
}

func (p *Pool) validateDeliveryMutation(ctx context.Context, identity ServiceIdentity, id, errorCode string, delay time.Duration, stage string) error {
	if p == nil || p.inner == nil {
		return &Error{Stage: stage, Cause: fmt.Errorf("database pool is unavailable")}
	}
	if ctx == nil {
		return &Error{Stage: stage, Cause: fmt.Errorf("context is required")}
	}
	if p.identity != identity {
		return &Error{Stage: stage, Cause: fmt.Errorf("database identity is not authorized")}
	}
	if strings.TrimSpace(id) == "" {
		return &Error{Stage: stage, Cause: fmt.Errorf("delivery identifier is required")}
	}
	if strings.TrimSpace(errorCode) == "" || len(errorCode) > 64 {
		return &Error{Stage: stage, Cause: fmt.Errorf("delivery error code is outside the boundary")}
	}
	if delay < time.Second || delay > 24*time.Hour {
		return &Error{Stage: stage, Cause: fmt.Errorf("retry delay is outside the boundary")}
	}
	return nil
}

func (p *Pool) validateDeliveryIdentifier(ctx context.Context, identity ServiceIdentity, id, stage string) error {
	if p == nil || p.inner == nil {
		return &Error{Stage: stage, Cause: fmt.Errorf("database pool is unavailable")}
	}
	if ctx == nil {
		return &Error{Stage: stage, Cause: fmt.Errorf("context is required")}
	}
	if p.identity != identity {
		return &Error{Stage: stage, Cause: fmt.Errorf("database identity is not authorized")}
	}
	if strings.TrimSpace(id) == "" {
		return &Error{Stage: stage, Cause: fmt.Errorf("delivery identifier is required")}
	}
	return nil
}

func boundedJSON(value string, maximum int) (json.RawMessage, bool) {
	if len(value) == 0 || len(value) > maximum || !json.Valid([]byte(value)) {
		return nil, true
	}
	return append(json.RawMessage(nil), value...), false
}
