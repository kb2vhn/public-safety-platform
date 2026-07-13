-- ============================================================================
-- Migration: 093_workload_registry_performance_budgets_and_resource_governance.sql
-- Title: Workload registry performance budgets and resource governance
-- Layer: Platform Foundation
-- Status: INITIAL REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

DO $dependency_check$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id = '092_resilience_availability_recovery_and_continuity'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 092_resilience_availability_recovery_and_continuity is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE performance.workload_definitions (
    workload_definition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workload_key text NOT NULL UNIQUE,
    workload_class text NOT NULL,
    service_id uuid REFERENCES service.platform_services(service_id),
    component_name text NOT NULL,
    owner_reference text NOT NULL,
    purpose text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE performance.resource_budgets (
    resource_budget_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workload_definition_id uuid NOT NULL REFERENCES performance.workload_definitions(workload_definition_id),
    budget_type text NOT NULL,
    limit_value numeric NOT NULL,
    unit text NOT NULL,
    enforcement_mode text NOT NULL DEFAULT 'ALERT',
    valid_from timestamptz NOT NULL,
    valid_until timestamptz
);

CREATE TABLE performance.query_registry (
    query_registry_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workload_definition_id uuid NOT NULL REFERENCES performance.workload_definitions(workload_definition_id),
    query_fingerprint text NOT NULL,
    query_name text NOT NULL,
    source_reference text NOT NULL,
    expected_cardinality bigint,
    expected_frequency text,
    owner_reference text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE',
    UNIQUE(workload_definition_id,query_fingerprint)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '093_workload_registry_performance_budgets_and_resource_governance',
    p_migration_name     => 'Workload registry performance budgets and resource governance',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created workload registry performance budgets and resource governance objects.'
);

COMMIT;
