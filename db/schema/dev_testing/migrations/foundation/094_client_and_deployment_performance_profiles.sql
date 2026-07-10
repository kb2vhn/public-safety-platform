-- ============================================================================
-- Migration: 094_client_and_deployment_performance_profiles.sql
-- Title: Client and deployment performance profiles
-- Layer: Platform Foundation
-- Status: INITIAL REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '10min';
SET LOCAL idle_in_transaction_session_timeout = '10min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

DO $dependency_check$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM foundation_meta.applied_migrations
        WHERE migration_id = '093_workload_registry_performance_budgets_and_resource_governance'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 093_workload_registry_performance_budgets_and_resource_governance is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE performance.deployment_classes (
    deployment_class_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    deployment_class_key text NOT NULL UNIQUE,
    title text NOT NULL,
    cpu_vcpu integer NOT NULL,
    memory_mb integer NOT NULL,
    storage_gb integer NOT NULL,
    intended_use text NOT NULL
);

CREATE TABLE performance.client_reference_profiles (
    client_reference_profile_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_key text NOT NULL UNIQUE,
    title text NOT NULL,
    cpu_description text NOT NULL,
    memory_mb integer NOT NULL,
    display_count integer NOT NULL,
    display_resolution text NOT NULL,
    graphics_requirement text NOT NULL,
    network_profile text NOT NULL,
    status text NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE performance.performance_test_results (
    performance_test_result_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    workload_definition_id uuid REFERENCES performance.workload_definitions(workload_definition_id),
    deployment_class_id uuid REFERENCES performance.deployment_classes(deployment_class_id),
    client_reference_profile_id uuid REFERENCES performance.client_reference_profiles(client_reference_profile_id),
    test_name text NOT NULL,
    tested_at timestamptz NOT NULL,
    result text NOT NULL,
    measurements jsonb NOT NULL,
    evidence_reference text
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '094_client_and_deployment_performance_profiles',
    p_migration_name     => 'Client and deployment performance profiles',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created client and deployment performance profiles objects.'
);

COMMIT;
