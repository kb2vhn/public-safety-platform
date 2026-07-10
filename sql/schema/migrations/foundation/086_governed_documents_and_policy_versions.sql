-- ============================================================================
-- Migration: 086_governed_documents_and_policy_versions.sql
-- Title: Governed documents and policy versions
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
        WHERE migration_id = '084_lifecycle_and_historical_lineage'
    ) THEN
        RAISE EXCEPTION
            USING ERRCODE = 'object_not_in_prerequisite_state',
                  MESSAGE = 'Required migration 084_lifecycle_and_historical_lineage is not registered';
    END IF;
END;
$dependency_check$;


CREATE TABLE governance.governed_documents (
    governed_document_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_key text NOT NULL UNIQUE,
    title text NOT NULL,
    document_type text NOT NULL,
    issuing_authority text NOT NULL
);

CREATE TABLE governance.governed_document_versions (
    governed_document_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    governed_document_id uuid NOT NULL REFERENCES governance.governed_documents(governed_document_id),
    version_label text NOT NULL,
    revision_number integer,
    status text NOT NULL DEFAULT 'DRAFT',
    approved_at timestamptz,
    effective_from timestamptz,
    effective_until timestamptz,
    approving_authority_reference text,
    content_hash bytea NOT NULL,
    storage_reference text NOT NULL,
    supersedes_version_id uuid REFERENCES governance.governed_document_versions(governed_document_version_id),
    decision_id uuid REFERENCES decision.decision_records(decision_id),
    UNIQUE(governed_document_id,version_label)
);

CREATE TABLE governance.policy_rules (
    policy_rule_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    governed_document_version_id uuid NOT NULL REFERENCES governance.governed_document_versions(governed_document_version_id),
    rule_key text NOT NULL,
    clause_reference text,
    executable_rule_reference text,
    rule_hash bytea,
    UNIQUE(governed_document_version_id,rule_key)
);

SELECT foundation_meta.register_migration(
    p_migration_id       => '086_governed_documents_and_policy_versions',
    p_migration_name     => 'Governed documents and policy versions',
    p_migration_layer    => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes              => 'Created governed documents and policy versions objects.'
);

COMMIT;
