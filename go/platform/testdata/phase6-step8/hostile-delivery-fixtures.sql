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
    '81000000-0000-0000-0000-000000000001',
    'step8-hostile-integration-contract',
    'http://127.0.0.1:1/database-selected-destination-is-metadata-only',
    'step8-hostile-adapter',
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
('81100000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000001','STEP8_SUCCESS','TEST_RECORD','success','{"fixture":"integration-success"}','INTERNAL',statement_timestamp()-interval '8 minutes',statement_timestamp()-interval '8 minutes','PENDING',0),
('81100000-0000-0000-0000-000000000002','81000000-0000-0000-0000-000000000001','STEP8_TIMEOUT','TEST_RECORD','timeout','{"fixture":"integration-timeout"}','INTERNAL',statement_timestamp()-interval '7 minutes',statement_timestamp()-interval '7 minutes','PENDING',0),
('81100000-0000-0000-0000-000000000003','81000000-0000-0000-0000-000000000001','STEP8_DISCONNECT','TEST_RECORD','disconnect','{"fixture":"integration-disconnect"}','INTERNAL',statement_timestamp()-interval '6 minutes',statement_timestamp()-interval '6 minutes','PENDING',0),
('81100000-0000-0000-0000-000000000004','81000000-0000-0000-0000-000000000001','STEP8_UNAVAILABLE','TEST_RECORD','unavailable','{"fixture":"integration-unavailable"}','INTERNAL',statement_timestamp()-interval '5 minutes',statement_timestamp()-interval '5 minutes','PENDING',0),
('81100000-0000-0000-0000-000000000005','81000000-0000-0000-0000-000000000001','STEP8_REJECTED','TEST_RECORD','rejected','{"fixture":"integration-rejected"}','INTERNAL',statement_timestamp()-interval '4 minutes',statement_timestamp()-interval '4 minutes','PENDING',0),
('81100000-0000-0000-0000-000000000006','81000000-0000-0000-0000-000000000001','STEP8_REDIRECT','TEST_RECORD','redirect','{"fixture":"integration-redirect"}','INTERNAL',statement_timestamp()-interval '3 minutes',statement_timestamp()-interval '3 minutes','PENDING',0),
('81100000-0000-0000-0000-000000000007','81000000-0000-0000-0000-000000000001','STEP8_MALFORMED','TEST_RECORD','malformed','{"fixture":"integration-malformed"}','INTERNAL',statement_timestamp()-interval '2 minutes',statement_timestamp()-interval '2 minutes','PENDING',0),
('81100000-0000-0000-0000-000000000008','81000000-0000-0000-0000-000000000001','STEP8_LARGE_SUCCESS','TEST_RECORD','large-success','{"fixture":"integration-large-success"}','INTERNAL',statement_timestamp()-interval '1 minute',statement_timestamp()-interval '1 minute','PENDING',0);

INSERT INTO observability.components (
    component_id,
    component_key,
    component_type,
    owner_reference,
    status
) VALUES (
    '82000000-0000-0000-0000-000000000001',
    'step8-hostile-component',
    'TEST_COMPONENT',
    'phase6-step8',
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
('82100000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','STEP8_SUCCESS','INFO','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8'),
('82100000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000001','STEP8_TIMEOUT','WARNING','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8'),
('82100000-0000-0000-0000-000000000003','82000000-0000-0000-0000-000000000001','STEP8_DISCONNECT','WARNING','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8'),
('82100000-0000-0000-0000-000000000004','82000000-0000-0000-0000-000000000001','STEP8_UNAVAILABLE','WARNING','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8'),
('82100000-0000-0000-0000-000000000005','82000000-0000-0000-0000-000000000001','STEP8_REJECTED','ERROR','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8'),
('82100000-0000-0000-0000-000000000006','82000000-0000-0000-0000-000000000001','STEP8_REDIRECT','ERROR','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8'),
('82100000-0000-0000-0000-000000000007','82000000-0000-0000-0000-000000000001','STEP8_MALFORMED','ERROR','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8'),
('82100000-0000-0000-0000-000000000008','82000000-0000-0000-0000-000000000001','STEP8_LARGE_SUCCESS','INFO','OPEN',statement_timestamp(),statement_timestamp(),'phase6-step8');

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
    '82200000-0000-0000-0000-000000000001',
    'step8-hostile-monitoring-subscription',
    'RELAY',
    'http://127.0.0.1:1/database-selected-destination-is-metadata-only',
    '{"severity":["INFO","WARNING","ERROR"]}',
    'ACTIVE',
    3,
    100,
    'phase6-step8'
);

INSERT INTO observability.monitoring_delivery_state (
    monitoring_delivery_state_id,
    monitoring_subscription_id,
    health_event_id,
    delivery_status,
    attempt_count
) VALUES
('82300000-0000-0000-0000-000000000001','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000001','PENDING',0),
('82300000-0000-0000-0000-000000000002','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000002','PENDING',0),
('82300000-0000-0000-0000-000000000003','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000003','PENDING',0),
('82300000-0000-0000-0000-000000000004','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000004','PENDING',0),
('82300000-0000-0000-0000-000000000005','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000005','PENDING',0),
('82300000-0000-0000-0000-000000000006','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000006','PENDING',0),
('82300000-0000-0000-0000-000000000007','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000007','PENDING',2),
('82300000-0000-0000-0000-000000000008','82200000-0000-0000-0000-000000000001','82100000-0000-0000-0000-000000000008','PENDING',0);

COMMIT;

SELECT 'integration_rows|' || count(*)::text
FROM integration.outbox_events
WHERE integration_contract_id = '81000000-0000-0000-0000-000000000001';
SELECT 'monitoring_rows|' || count(*)::text
FROM observability.monitoring_delivery_state
WHERE monitoring_subscription_id = '82200000-0000-0000-0000-000000000001';
