-- ============================================================================
-- Migration: 000_platform_initialization.sql
-- Layer: Platform Foundation
-- Status: INITIAL REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '5min';
SET LOCAL idle_in_transaction_session_timeout = '5min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

DO $platform_version_check$
BEGIN
    IF current_setting('server_version_num')::integer < 180000 THEN
        RAISE EXCEPTION
            USING ERRCODE = 'feature_not_supported',
                  MESSAGE = 'Platform Foundation requires PostgreSQL 18 or newer',
                  DETAIL = format('Detected server_version_num=%s.', current_setting('server_version_num'));
    END IF;
END;
$platform_version_check$;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

CREATE SCHEMA IF NOT EXISTS foundation_meta;
CREATE SCHEMA IF NOT EXISTS trust;
CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS organization;
CREATE SCHEMA IF NOT EXISTS service;
CREATE SCHEMA IF NOT EXISTS attestation;
CREATE SCHEMA IF NOT EXISTS approval;
CREATE SCHEMA IF NOT EXISTS access_control;
CREATE SCHEMA IF NOT EXISTS decision;
CREATE SCHEMA IF NOT EXISTS governance;
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE SCHEMA IF NOT EXISTS risk;
CREATE SCHEMA IF NOT EXISTS resilience;
CREATE SCHEMA IF NOT EXISTS performance;
CREATE SCHEMA IF NOT EXISTS observability;
CREATE SCHEMA IF NOT EXISTS integration;
CREATE SCHEMA IF NOT EXISTS security_validation;

DO $revoke_schema_privileges$
DECLARE
    v_schema name;
BEGIN
    FOREACH v_schema IN ARRAY ARRAY[
        'foundation_meta'::name,'trust'::name,'identity'::name,'organization'::name,
        'service'::name,'attestation'::name,'approval'::name,'access_control'::name,
        'decision'::name,'governance'::name,'compliance'::name,'risk'::name,
        'resilience'::name,'performance'::name,'observability'::name,'integration'::name,
        'security_validation'::name
    ]
    LOOP
        EXECUTE format('REVOKE ALL ON SCHEMA %I FROM PUBLIC', v_schema);
    END LOOP;
END;
$revoke_schema_privileges$;

CREATE TABLE foundation_meta.applied_migrations (
    migration_id            text PRIMARY KEY,
    migration_name          text NOT NULL,
    migration_layer         text NOT NULL,
    migration_checksum      text,
    applied_at              timestamptz NOT NULL DEFAULT clock_timestamp(),
    applied_by              name NOT NULL DEFAULT session_user,
    database_name           name NOT NULL DEFAULT current_database(),
    server_version_num      integer NOT NULL DEFAULT current_setting('server_version_num')::integer,
    application_name        text NOT NULL DEFAULT COALESCE(NULLIF(current_setting('application_name', true), ''), 'unspecified'),
    transaction_id          bigint NOT NULL DEFAULT txid_current(),
    notes                   text,
    CONSTRAINT applied_migrations_id_ck CHECK (migration_id ~ '^[0-9]{3}(_[a-z0-9]+)*$'),
    CONSTRAINT applied_migrations_name_ck CHECK (btrim(migration_name) <> ''),
    CONSTRAINT applied_migrations_layer_ck CHECK (btrim(migration_layer) <> ''),
    CONSTRAINT applied_migrations_checksum_ck CHECK (migration_checksum IS NULL OR migration_checksum ~ '^[0-9a-f]{64}$')
);

CREATE TABLE foundation_meta.schema_registry (
    schema_name              name PRIMARY KEY,
    capability_key           text NOT NULL UNIQUE,
    architectural_layer      text NOT NULL,
    purpose                  text NOT NULL,
    created_by_migration_id  text NOT NULL,
    active                   boolean NOT NULL DEFAULT true,
    registered_at            timestamptz NOT NULL DEFAULT clock_timestamp(),
    retired_at               timestamptz,
    CONSTRAINT schema_registry_key_ck CHECK (capability_key ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT schema_registry_layer_ck CHECK (architectural_layer IN ('FOUNDATION','DOMAIN','DEPLOYMENT','VALIDATION')),
    CONSTRAINT schema_registry_purpose_ck CHECK (btrim(purpose) <> ''),
    CONSTRAINT schema_registry_lifecycle_ck CHECK (
        (active AND retired_at IS NULL) OR (NOT active AND retired_at IS NOT NULL)
    )
);

INSERT INTO foundation_meta.schema_registry
(schema_name, capability_key, architectural_layer, purpose, created_by_migration_id)
VALUES
('foundation_meta','foundation_metadata','FOUNDATION','Migration and architectural metadata.','000_platform_initialization'),
('trust','cryptographic_and_device_trust','FOUNDATION','Trust providers, authorities, devices, certificates, and revocation.','000_platform_initialization'),
('identity','identity_and_lifecycle','FOUNDATION','Identities, persons, mappings, and lifecycle.','000_platform_initialization'),
('organization','organizations_and_jurisdictions','FOUNDATION','Organizations, relationships, jurisdictions, and authority purposes.','000_platform_initialization'),
('service','services_and_federation','FOUNDATION','Services, deployments, participation, federation, and configuration.','000_platform_initialization'),
('attestation','attestations_and_eligibility','FOUNDATION','Attestation authorities, attestations, and access eligibility.','000_platform_initialization'),
('approval','approval_framework','FOUNDATION','Approval policies, requests, stages, and actions.','000_platform_initialization'),
('access_control','authority_and_authorization','FOUNDATION','Authority, purpose, sessions, assertions, and leases.','000_platform_initialization'),
('decision','decision_records','FOUNDATION','Decision Records, evaluations, chains, and integrity metadata.','000_platform_initialization'),
('governance','data_and_document_governance','FOUNDATION','Classification, ownership, custody, documents, policy, and lineage.','000_platform_initialization'),
('compliance','compliance_and_controls','FOUNDATION','Controls, profiles, implementations, evidence, assessments, and findings.','000_platform_initialization'),
('risk','risk_and_threats','FOUNDATION','Risk, threats, abuse cases, treatments, exceptions, and compensating controls.','000_platform_initialization'),
('resilience','resilience_and_recovery','FOUNDATION','Criticality, continuity, backup, recovery, and reconciliation.','000_platform_initialization'),
('performance','performance_and_resource_governance','FOUNDATION','Workloads, budgets, capacity, and performance profiles.','000_platform_initialization'),
('observability','observability_and_telemetry','FOUNDATION','Health, metrics, telemetry, subscriptions, and delivery state.','000_platform_initialization'),
('integration','provider_integrations','FOUNDATION','Provider-neutral contracts, outbox, and adapter delivery state.','000_platform_initialization'),
('security_validation','security_validation','VALIDATION','Validation views and assertions.','000_platform_initialization');

CREATE FUNCTION foundation_meta.register_migration(
    p_migration_id text,
    p_migration_name text,
    p_migration_layer text,
    p_migration_checksum text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, foundation_meta
AS $$
DECLARE
    v_existing foundation_meta.applied_migrations%ROWTYPE;
BEGIN
    IF p_migration_id IS NULL OR p_migration_id !~ '^[0-9]{3}(_[a-z0-9]+)*$' THEN
        RAISE EXCEPTION USING ERRCODE='invalid_parameter_value', MESSAGE='Invalid migration identifier';
    END IF;
    IF p_migration_name IS NULL OR btrim(p_migration_name) = '' THEN
        RAISE EXCEPTION USING ERRCODE='invalid_parameter_value', MESSAGE='Migration name must not be empty';
    END IF;
    IF p_migration_layer IS NULL OR btrim(p_migration_layer) = '' THEN
        RAISE EXCEPTION USING ERRCODE='invalid_parameter_value', MESSAGE='Migration layer must not be empty';
    END IF;
    IF p_migration_checksum IS NOT NULL AND p_migration_checksum !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION USING ERRCODE='invalid_parameter_value', MESSAGE='Checksum must be lowercase SHA-256';
    END IF;

    SELECT * INTO v_existing
    FROM foundation_meta.applied_migrations
    WHERE migration_id = p_migration_id;

    IF FOUND THEN
        IF v_existing.migration_name IS DISTINCT FROM p_migration_name
           OR v_existing.migration_layer IS DISTINCT FROM p_migration_layer
           OR v_existing.migration_checksum IS DISTINCT FROM p_migration_checksum THEN
            RAISE EXCEPTION USING ERRCODE='integrity_constraint_violation',
                MESSAGE='Migration identifier already registered with different metadata';
        END IF;
        RETURN;
    END IF;

    INSERT INTO foundation_meta.applied_migrations
    (migration_id,migration_name,migration_layer,migration_checksum,notes)
    VALUES
    (p_migration_id,p_migration_name,p_migration_layer,p_migration_checksum,p_notes);
END;
$$;

SELECT foundation_meta.register_migration(
    '000_platform_initialization',
    'Platform initialization',
    'FOUNDATION',
    NULL,
    'Created Foundation schemas and migration registries.'
);

COMMIT;
