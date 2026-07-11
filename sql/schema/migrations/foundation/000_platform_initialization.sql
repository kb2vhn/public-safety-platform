-- ============================================================================
-- Migration: 000_platform_initialization.sql
-- Title: Platform Initialization
-- Layer: Platform Foundation
-- Status: REVIEW CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Design policy:
--   PostgreSQL 18 is the supported baseline.
--   Mature PostgreSQL features are preferred.
--   Features introduced only in PostgreSQL 18 should be avoided unless they
--   are the only sound solution.
--
-- Purpose:
--   Establish the domain-neutral Platform Foundation namespaces, PostgreSQL
--   extension boundary, migration registry, schema registry, and baseline
--   database security invariants.
--
-- Owns:
--   - PostgreSQL version validation
--   - Dedicated PostgreSQL extension schema
--   - pgcrypto extension installation
--   - Platform Foundation schemas
--   - Applied migration registry
--   - Foundation schema registry
--   - Migration registration function
--   - Migration serialization lock
--
-- Does not own:
--   - Runtime database roles
--   - Application login roles
--   - Trust providers or devices
--   - Human or service identities
--   - Organizations or jurisdictions
--   - Authorization policy
--   - Domain objects such as CAD, RMS, or Evidence
--
-- Security invariants:
--   - PUBLIC cannot create objects in the public schema.
--   - PUBLIC receives no privileges on Foundation schemas.
--   - PostgreSQL extension objects are isolated in the extensions schema.
--   - No application role or unrestricted administrative role is created.
--   - Schema ownership remains with the migration identity until later
--     deployment-role and ownership migrations are approved.
--
-- Operational invariants:
--   - Only one Platform Foundation migration runner may operate at a time.
--   - Every successfully applied migration is registered once.
--   - Reusing a migration identifier with different metadata fails.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '5min';
SET LOCAL idle_in_transaction_session_timeout = '5min';

-- Prevent concurrent Platform Foundation migration runners.
SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('platform-foundation-migrations')
);

-- Require the supported PostgreSQL major version.
DO $platform_version_check$
BEGIN
    IF current_setting('server_version_num')::integer < 180000 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'feature_not_supported',
                MESSAGE = 'Platform Foundation requires PostgreSQL 18 or newer',
                DETAIL = format(
                    'Detected server_version_num=%s.',
                    current_setting('server_version_num')
                ),
                HINT = 'Install the current supported PostgreSQL 18 minor release.';
    END IF;
END;
$platform_version_check$;

-- Prevent untrusted users from creating objects that could shadow trusted
-- names in the public schema.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- ============================================================================
-- PostgreSQL extension boundary
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS extensions;

COMMENT ON SCHEMA extensions IS
    'Approved PostgreSQL extension objects isolated from application and Foundation schemas.';

REVOKE ALL ON SCHEMA extensions FROM PUBLIC;

CREATE EXTENSION IF NOT EXISTS pgcrypto
    WITH SCHEMA extensions;

-- ============================================================================
-- Platform Foundation schemas
-- ============================================================================

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

COMMENT ON SCHEMA foundation_meta IS
    'Platform migration, schema, version, and architectural metadata.';

COMMENT ON SCHEMA trust IS
    'Cryptographic trust providers, certificate authorities, devices, certificates, and revocation state.';

COMMENT ON SCHEMA identity IS
    'Domain-neutral identities, persons, identity-provider mappings, and identity lifecycle records.';

COMMENT ON SCHEMA organization IS
    'Organizations, organizational units, relationships, jurisdictions, and authority-purpose boundaries.';

COMMENT ON SCHEMA service IS
    'Platform services, deployments, participation agreements, federation, and governed configuration.';

COMMENT ON SCHEMA attestation IS
    'Attestation authorities, organizational attestations, and access eligibility records.';

COMMENT ON SCHEMA approval IS
    'Generic approval policies, requests, stages, actions, independence, and lifecycle records.';

COMMENT ON SCHEMA access_control IS
    'Authority definitions, grants, purpose, sessions, Trust Assertions, and Authorization Leases.';

COMMENT ON SCHEMA decision IS
    'Append-only Decision Records, evaluation records, Justification Chains, and integrity metadata.';

COMMENT ON SCHEMA governance IS
    'Data classification, ownership, custody, governed documents, policies, and historical lineage.';

COMMENT ON SCHEMA compliance IS
    'Framework-neutral controls, compliance profiles, implementations, assurance artifacts, assessments, and findings.';

COMMENT ON SCHEMA risk IS
    'Risk records, threats, abuse cases, treatments, exceptions, and compensating controls.';

COMMENT ON SCHEMA resilience IS
    'Service criticality, continuity, degraded operation, backup, failover, recovery, and reconciliation.';

COMMENT ON SCHEMA performance IS
    'Workload registry, resource budgets, capacity, efficiency, and client or deployment performance profiles.';

COMMENT ON SCHEMA observability IS
    'Provider-neutral health, metrics, operational telemetry, subscriptions, and delivery state.';

COMMENT ON SCHEMA integration IS
    'Provider-neutral integration contracts, transactional outbox records, and adapter delivery state.';

COMMENT ON SCHEMA security_validation IS
    'Read-only validation views and assertions for database security and architectural invariants.';

-- Explicitly remove PUBLIC privileges from every Foundation schema.
DO $revoke_schema_privileges$
DECLARE
    v_schema name;
BEGIN
    FOREACH v_schema IN ARRAY ARRAY[
        'extensions'::name,
        'foundation_meta'::name,
        'trust'::name,
        'identity'::name,
        'organization'::name,
        'service'::name,
        'attestation'::name,
        'approval'::name,
        'access_control'::name,
        'decision'::name,
        'governance'::name,
        'compliance'::name,
        'risk'::name,
        'resilience'::name,
        'performance'::name,
        'observability'::name,
        'integration'::name,
        'security_validation'::name
    ]
    LOOP
        EXECUTE format(
            'REVOKE ALL ON SCHEMA %I FROM PUBLIC',
            v_schema
        );
    END LOOP;
END;
$revoke_schema_privileges$;

-- ============================================================================
-- Applied migration registry
-- ============================================================================

CREATE TABLE foundation_meta.applied_migrations (
    migration_id            text                     PRIMARY KEY,
    migration_name          text                     NOT NULL,
    migration_layer         text                     NOT NULL,
    migration_checksum      text,
    applied_at              timestamp with time zone NOT NULL
                                                   DEFAULT clock_timestamp(),
    applied_by              name                     NOT NULL
                                                   DEFAULT session_user,
    database_name           name                     NOT NULL
                                                   DEFAULT current_database(),
    server_version_num      integer                  NOT NULL
                                                   DEFAULT current_setting(
                                                       'server_version_num'
                                                   )::integer,
    application_name        text                     NOT NULL
                                                   DEFAULT COALESCE(
                                                       NULLIF(
                                                           current_setting(
                                                               'application_name',
                                                               true
                                                           ),
                                                           ''
                                                       ),
                                                       'unspecified'
                                                   ),
    transaction_id          bigint                   NOT NULL
                                                   DEFAULT txid_current(),
    notes                   text,

    CONSTRAINT applied_migrations_id_format_ck
        CHECK (
            migration_id ~ '^[0-9]{3}(_[a-z0-9]+)*$'
        ),

    CONSTRAINT applied_migrations_name_nonempty_ck
        CHECK (
            btrim(migration_name) <> ''
        ),

    CONSTRAINT applied_migrations_layer_nonempty_ck
        CHECK (
            btrim(migration_layer) <> ''
        ),

    CONSTRAINT applied_migrations_checksum_format_ck
        CHECK (
            migration_checksum IS NULL
            OR migration_checksum ~ '^[0-9a-f]{64}$'
        )
);

COMMENT ON TABLE foundation_meta.applied_migrations IS
    'Append-only registry of successfully applied platform migrations.';

COMMENT ON COLUMN foundation_meta.applied_migrations.migration_checksum IS
    'Optional lowercase SHA-256 checksum supplied by the migration runner.';

CREATE UNIQUE INDEX applied_migrations_layer_name_uq
    ON foundation_meta.applied_migrations (
        migration_layer,
        migration_name
    );

CREATE INDEX applied_migrations_applied_at_idx
    ON foundation_meta.applied_migrations (
        applied_at
    );

-- ============================================================================
-- Foundation schema registry
-- ============================================================================

CREATE TABLE foundation_meta.schema_registry (
    schema_name              name                     PRIMARY KEY,
    capability_key           text                     NOT NULL UNIQUE,
    architectural_layer      text                     NOT NULL,
    purpose                  text                     NOT NULL,
    created_by_migration_id  text                     NOT NULL,
    active                   boolean                  NOT NULL DEFAULT true,
    registered_at            timestamp with time zone NOT NULL
                                                   DEFAULT clock_timestamp(),
    retired_at               timestamp with time zone,

    CONSTRAINT schema_registry_capability_key_ck
        CHECK (
            capability_key ~ '^[a-z][a-z0-9_]*$'
        ),

    CONSTRAINT schema_registry_layer_ck
        CHECK (
            architectural_layer IN (
                'FOUNDATION',
                'DOMAIN',
                'DEPLOYMENT',
                'VALIDATION'
            )
        ),

    CONSTRAINT schema_registry_purpose_nonempty_ck
        CHECK (
            btrim(purpose) <> ''
        ),

    CONSTRAINT schema_registry_lifecycle_ck
        CHECK (
            (
                active = true
                AND retired_at IS NULL
            )
            OR
            (
                active = false
                AND retired_at IS NOT NULL
            )
        )
);

COMMENT ON TABLE foundation_meta.schema_registry IS
    'Registry describing each canonical schema and its architectural responsibility.';

INSERT INTO foundation_meta.schema_registry (
    schema_name,
    capability_key,
    architectural_layer,
    purpose,
    created_by_migration_id
)
VALUES
    (
        'extensions',
        'postgresql_extensions',
        'FOUNDATION',
        'Approved PostgreSQL extension objects isolated from application and Foundation schemas.',
        '000_platform_initialization'
    ),
    (
        'foundation_meta',
        'foundation_metadata',
        'FOUNDATION',
        'Migration, schema, version, and architectural metadata.',
        '000_platform_initialization'
    ),
    (
        'trust',
        'cryptographic_and_device_trust',
        'FOUNDATION',
        'Trust providers, certificate authorities, devices, certificates, and revocation.',
        '000_platform_initialization'
    ),
    (
        'identity',
        'identity_and_identity_lifecycle',
        'FOUNDATION',
        'Identities, persons, provider mappings, and lifecycle.',
        '000_platform_initialization'
    ),
    (
        'organization',
        'organizations_and_jurisdictions',
        'FOUNDATION',
        'Organizations, units, relationships, jurisdictions, and authority purposes.',
        '000_platform_initialization'
    ),
    (
        'service',
        'services_participation_and_federation',
        'FOUNDATION',
        'Services, deployments, participation agreements, federation, and governed configuration.',
        '000_platform_initialization'
    ),
    (
        'attestation',
        'attestations_and_access_eligibility',
        'FOUNDATION',
        'Attestation authorities, attestations, and scoped eligibility grants.',
        '000_platform_initialization'
    ),
    (
        'approval',
        'approval_framework',
        'FOUNDATION',
        'Approval policies, requests, stages, actions, independence, and lifecycle.',
        '000_platform_initialization'
    ),
    (
        'access_control',
        'authority_and_authorization',
        'FOUNDATION',
        'Authority, purpose, sessions, Trust Assertions, and Authorization Leases.',
        '000_platform_initialization'
    ),
    (
        'decision',
        'decision_record_repository',
        'FOUNDATION',
        'Decision Records, evaluations, Justification Chains, and integrity metadata.',
        '000_platform_initialization'
    ),
    (
        'governance',
        'data_and_document_governance',
        'FOUNDATION',
        'Classification, ownership, custody, governed documents, policies, and lineage.',
        '000_platform_initialization'
    ),
    (
        'compliance',
        'compliance_and_controls',
        'FOUNDATION',
        'Controls, profiles, implementations, assurance artifacts, assessments, and findings.',
        '000_platform_initialization'
    ),
    (
        'risk',
        'risk_threats_and_exceptions',
        'FOUNDATION',
        'Risk, threats, abuse cases, treatments, exceptions, and compensating controls.',
        '000_platform_initialization'
    ),
    (
        'resilience',
        'resilience_and_recovery',
        'FOUNDATION',
        'Criticality, continuity, degraded operation, backup, recovery, and reconciliation.',
        '000_platform_initialization'
    ),
    (
        'performance',
        'performance_and_resource_governance',
        'FOUNDATION',
        'Workloads, budgets, capacity, efficiency, and performance profiles.',
        '000_platform_initialization'
    ),
    (
        'observability',
        'observability_and_operational_telemetry',
        'FOUNDATION',
        'Health, metrics, telemetry, subscriptions, and monitoring delivery state.',
        '000_platform_initialization'
    ),
    (
        'integration',
        'provider_integrations',
        'FOUNDATION',
        'Provider-neutral contracts, outbox records, and adapter delivery state.',
        '000_platform_initialization'
    ),
    (
        'security_validation',
        'security_validation',
        'VALIDATION',
        'Validation views and assertions for database security and architecture.',
        '000_platform_initialization'
    );

-- ============================================================================
-- Migration registration function
-- ============================================================================

CREATE FUNCTION foundation_meta.register_migration(
    p_migration_id       text,
    p_migration_name     text,
    p_migration_layer    text,
    p_migration_checksum text DEFAULT NULL,
    p_notes              text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SET search_path = pg_catalog, foundation_meta
AS $function$
DECLARE
    v_existing foundation_meta.applied_migrations%ROWTYPE;
BEGIN
    IF p_migration_id IS NULL
       OR p_migration_id !~ '^[0-9]{3}(_[a-z0-9]+)*$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Invalid migration identifier',
                DETAIL = format(
                    'migration_id=%L',
                    p_migration_id
                );
    END IF;

    IF p_migration_name IS NULL
       OR btrim(p_migration_name) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Migration name must not be empty';
    END IF;

    IF p_migration_layer IS NULL
       OR btrim(p_migration_layer) = '' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Migration layer must not be empty';
    END IF;

    IF p_migration_checksum IS NOT NULL
       AND p_migration_checksum !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'invalid_parameter_value',
                MESSAGE = 'Migration checksum must be a lowercase SHA-256 value';
    END IF;

    SELECT *
      INTO v_existing
      FROM foundation_meta.applied_migrations
     WHERE migration_id = p_migration_id;

    IF FOUND THEN
        IF v_existing.migration_name IS DISTINCT FROM p_migration_name
           OR v_existing.migration_layer IS DISTINCT FROM p_migration_layer
           OR v_existing.migration_checksum IS DISTINCT FROM p_migration_checksum THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = 'integrity_constraint_violation',
                    MESSAGE = 'Migration identifier is already registered with different metadata',
                    DETAIL = format(
                        'migration_id=%s existing_name=%L requested_name=%L',
                        p_migration_id,
                        v_existing.migration_name,
                        p_migration_name
                    );
        END IF;

        -- Exact re-registration is harmless when a client loses its connection
        -- after the transaction commits and later retries the migration.
        RETURN;
    END IF;

    INSERT INTO foundation_meta.applied_migrations (
        migration_id,
        migration_name,
        migration_layer,
        migration_checksum,
        notes
    )
    VALUES (
        p_migration_id,
        p_migration_name,
        p_migration_layer,
        p_migration_checksum,
        p_notes
    );
END;
$function$;

COMMENT ON FUNCTION foundation_meta.register_migration(
    text,
    text,
    text,
    text,
    text
) IS
    'Registers a successfully applied migration and rejects identifier reuse with different metadata.';

REVOKE ALL
ON FUNCTION foundation_meta.register_migration(
    text,
    text,
    text,
    text,
    text
)
FROM PUBLIC;

-- Register this migration only after all initialization work succeeds.
SELECT foundation_meta.register_migration(
    p_migration_id       => '000_platform_initialization',
    p_migration_name     => 'Platform initialization',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created the extension boundary, Foundation schemas, and migration metadata registries.'
);

COMMIT;

