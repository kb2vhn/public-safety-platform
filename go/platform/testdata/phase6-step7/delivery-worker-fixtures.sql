\set ON_ERROR_STOP on

BEGIN;

INSERT INTO integration.integration_contracts (
    integration_contract_id,
    contract_key,
    external_system_name,
    adapter_name,
    adapter_version,
    source_of_truth_role,
    status,
    valid_from
) VALUES (
    '71000000-0000-0000-0000-000000000001',
    'step7-integration-contract',
    'step7-external-system',
    'step7-adapter',
    '1.0',
    'PLATFORM',
    'ACTIVE',
    statement_timestamp() - interval '1 hour'
);

INSERT INTO integration.outbox_events (
    outbox_event_id,
    integration_contract_id,
    event_type,
    aggregate_type,
    aggregate_id,
    payload,
    classification_reference,
    created_at,
    available_at,
    status,
    attempt_count
) VALUES
(
    '71100000-0000-0000-0000-000000000001',
    '71000000-0000-0000-0000-000000000001',
    'STEP7_CONCURRENT_A',
    'TEST_RECORD',
    'concurrent-a',
    '{"fixture":"integration-concurrent-a"}',
    'INTERNAL',
    statement_timestamp() - interval '4 minutes',
    statement_timestamp() - interval '4 minutes',
    'PENDING',
    0
),
(
    '71100000-0000-0000-0000-000000000002',
    '71000000-0000-0000-0000-000000000001',
    'STEP7_CONCURRENT_B',
    'TEST_RECORD',
    'concurrent-b',
    '{"fixture":"integration-concurrent-b"}',
    'INTERNAL',
    statement_timestamp() - interval '3 minutes',
    statement_timestamp() - interval '3 minutes',
    'PENDING',
    0
),
(
    '71100000-0000-0000-0000-000000000003',
    '71000000-0000-0000-0000-000000000001',
    'STEP7_SUCCESS',
    'TEST_RECORD',
    'success',
    '{"fixture":"integration-success"}',
    'INTERNAL',
    statement_timestamp() - interval '2 minutes',
    statement_timestamp() - interval '2 minutes',
    'PENDING',
    0
),
(
    '71100000-0000-0000-0000-000000000004',
    '71000000-0000-0000-0000-000000000001',
    'STEP7_RETRY',
    'TEST_RECORD',
    'retry',
    '{"fixture":"integration-retry"}',
    'INTERNAL',
    statement_timestamp() - interval '1 minute',
    statement_timestamp() - interval '1 minute',
    'PENDING',
    0
);

INSERT INTO observability.components (
    component_id,
    component_key,
    component_type,
    owner_reference,
    status
) VALUES (
    '72000000-0000-0000-0000-000000000001',
    'step7-component',
    'TEST_COMPONENT',
    'phase6-step7',
    'ACTIVE'
);

INSERT INTO observability.health_events (
    health_event_id,
    component_id,
    event_type,
    severity,
    status,
    first_observed_at,
    last_observed_at,
    owner_reference
) VALUES
(
    '72100000-0000-0000-0000-000000000001',
    '72000000-0000-0000-0000-000000000001',
    'STEP7_SUCCESS',
    'INFO',
    'OPEN',
    statement_timestamp(),
    statement_timestamp(),
    'phase6-step7'
),
(
    '72100000-0000-0000-0000-000000000002',
    '72000000-0000-0000-0000-000000000001',
    'STEP7_RETRY',
    'WARNING',
    'OPEN',
    statement_timestamp(),
    statement_timestamp(),
    'phase6-step7'
),
(
    '72100000-0000-0000-0000-000000000003',
    '72000000-0000-0000-0000-000000000001',
    'STEP7_FAILED',
    'ERROR',
    'OPEN',
    statement_timestamp(),
    statement_timestamp(),
    'phase6-step7'
);

INSERT INTO observability.monitoring_subscriptions (
    monitoring_subscription_id,
    subscription_key,
    destination_type,
    destination_reference,
    event_filter,
    status,
    max_retry_count,
    max_queue_depth,
    created_by_reference
) VALUES (
    '72200000-0000-0000-0000-000000000001',
    'step7-monitoring-subscription',
    'RELAY',
    'logical-monitoring-destination',
    '{"severity":["INFO","WARNING","ERROR"]}',
    'ACTIVE',
    2,
    100,
    'phase6-step7'
);

INSERT INTO observability.monitoring_delivery_state (
    monitoring_delivery_state_id,
    monitoring_subscription_id,
    health_event_id,
    delivery_status,
    attempt_count
) VALUES
(
    '72300000-0000-0000-0000-000000000001',
    '72200000-0000-0000-0000-000000000001',
    '72100000-0000-0000-0000-000000000001',
    'PENDING',
    0
),
(
    '72300000-0000-0000-0000-000000000002',
    '72200000-0000-0000-0000-000000000001',
    '72100000-0000-0000-0000-000000000002',
    'PENDING',
    0
),
(
    '72300000-0000-0000-0000-000000000003',
    '72200000-0000-0000-0000-000000000001',
    '72100000-0000-0000-0000-000000000003',
    'PENDING',
    1
);

COMMIT;

SELECT 'integration_success|' || '71100000-0000-0000-0000-000000000003';
SELECT 'integration_retry|' || '71100000-0000-0000-0000-000000000004';
SELECT 'monitoring_success|' || '72300000-0000-0000-0000-000000000001';
SELECT 'monitoring_retry|' || '72300000-0000-0000-0000-000000000002';
SELECT 'monitoring_failed|' || '72300000-0000-0000-0000-000000000003';
