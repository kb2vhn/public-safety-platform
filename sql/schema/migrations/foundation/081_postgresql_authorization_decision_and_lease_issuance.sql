-- ============================================================================
-- Migration: 081_postgresql_authorization_decision_and_lease_issuance.sql
-- Title: PostgreSQL authorization decision and lease issuance structure
-- Layer: Platform Foundation
-- Status: PHASE 3 STEP 4 IMPLEMENTATION CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================
--
-- Purpose:
-- Establish the typed relational boundary required before controlled
-- authorization policy selection, Decision Record finalization, and
-- Authorization Lease issuance are implemented.
--
-- Step 3 added deterministic policy resolution, controlled policy binding,
-- required-stage closure, and finalization-once Decision Record behavior.
-- Step 4 adds controlled lease issuance, exact-context usability, atomic use,
-- materialized expiration, and revocation behavior.
--
-- Accepted-boundary rule:
-- Migrations 055, 060, 065, 070, 072, 075, and 080 remain unchanged.
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
        WHERE migration_id = '080_decision_record_repository'
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'object_not_in_prerequisite_state',
                MESSAGE = 'Required migration 080_decision_record_repository is not registered';
    END IF;
END;
$dependency_check$;

-- ---------------------------------------------------------------------------
-- Deterministic Authorization Policy Version applicability structure
-- ---------------------------------------------------------------------------

ALTER TABLE access_control.authorization_policy_versions
    ADD COLUMN requester_organization_id uuid
        REFERENCES organization.organizations(organization_id),
    ADD COLUMN governed_scope_id uuid
        REFERENCES organization.governed_scopes(governed_scope_id),
    ADD COLUMN applies_to_all_governed_scopes boolean
        NOT NULL DEFAULT false,
    ADD COLUMN protected_target_type text,
    ADD COLUMN protected_target_reference text,
    ADD COLUMN applies_to_all_targets boolean
        NOT NULL DEFAULT false,
    ADD COLUMN classification_key text,
    ADD COLUMN lease_audience text,
    ADD COLUMN selection_priority integer
        NOT NULL DEFAULT 100,
    ADD CONSTRAINT authorization_policy_versions_scope_exclusive_ck
        CHECK (
            NOT (
                governed_scope_id IS NOT NULL
                AND applies_to_all_governed_scopes
            )
        ),
    ADD CONSTRAINT authorization_policy_versions_scope_requirement_ck
        CHECK (
            NOT governed_scope_required
            OR governed_scope_id IS NOT NULL
            OR applies_to_all_governed_scopes
        ),
    ADD CONSTRAINT authorization_policy_versions_target_pair_ck
        CHECK (
            (
                protected_target_type IS NULL
                AND protected_target_reference IS NULL
            )
            OR
            (
                protected_target_type IS NOT NULL
                AND protected_target_reference IS NOT NULL
                AND protected_target_type ~ '^[A-Z][A-Z0-9_]*$'
                AND btrim(protected_target_reference) <> ''
            )
        ),
    ADD CONSTRAINT authorization_policy_versions_target_exclusive_ck
        CHECK (
            NOT (
                applies_to_all_targets
                AND protected_target_type IS NOT NULL
            )
        ),
    ADD CONSTRAINT authorization_policy_versions_target_requirement_ck
        CHECK (
            NOT protected_target_required
            OR applies_to_all_targets
            OR protected_target_type IS NOT NULL
        ),
    ADD CONSTRAINT authorization_policy_versions_classification_key_ck
        CHECK (
            classification_key IS NULL
            OR classification_key ~ '^[A-Z][A-Z0-9_]*$'
        ),
    ADD CONSTRAINT authorization_policy_versions_lease_audience_ck
        CHECK (
            lease_audience IS NULL
            OR btrim(lease_audience) <> ''
        ),
    ADD CONSTRAINT authorization_policy_versions_priority_ck
        CHECK (selection_priority > 0);

COMMENT ON COLUMN
    access_control.authorization_policy_versions.requester_organization_id IS
    'Optional exact requester-organization applicability for deterministic policy selection.';

COMMENT ON COLUMN
    access_control.authorization_policy_versions.governed_scope_id IS
    'Optional exact Governed Scope applicability. This is distinct from governed_scope_required.';

COMMENT ON COLUMN
    access_control.authorization_policy_versions.selection_priority IS
    'Explicit deterministic precedence after applicability and specificity are established. Lower values sort before higher values; equal applicable precedence remains ambiguous and must fail closed.';

CREATE INDEX authorization_policy_versions_phase3_lookup_idx
    ON access_control.authorization_policy_versions(
        decision_class,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        requester_organization_id,
        governed_scope_id,
        protected_target_type,
        classification_key,
        status,
        selection_priority,
        valid_from,
        valid_until
    );

-- ---------------------------------------------------------------------------
-- Exact policy-stage rule structure
-- ---------------------------------------------------------------------------

ALTER TABLE access_control.authorization_policy_stage_requirements
    ADD COLUMN not_required_reason_code text,
    ADD COLUMN not_required_rule_reference text,
    ADD COLUMN supporting_record_required boolean
        NOT NULL DEFAULT true,
    ADD CONSTRAINT authorization_policy_stage_not_required_rule_ck
        CHECK (
            (
                required
                AND not_required_reason_code IS NULL
                AND not_required_rule_reference IS NULL
            )
            OR
            (
                NOT required
                AND not_required_reason_code IS NOT NULL
                AND not_required_rule_reference IS NOT NULL
                AND not_required_reason_code ~ '^[A-Z][A-Z0-9_]*$'
                AND btrim(not_required_rule_reference) <> ''
            )
        ),
    ADD CONSTRAINT authorization_policy_stage_mapping_uq
        UNIQUE (
            authorization_policy_stage_requirement_id,
            authorization_policy_version_id,
            stage_order,
            stage_key,
            required
        );

COMMENT ON COLUMN
    access_control.authorization_policy_stage_requirements.not_required_reason_code IS
    'Stable reason code proving why an optional stage may resolve as NOT_REQUIRED.';

COMMENT ON COLUMN
    access_control.authorization_policy_stage_requirements.not_required_rule_reference IS
    'Exact policy-rule or governed-document reference supporting NOT_REQUIRED.';

COMMENT ON COLUMN
    access_control.authorization_policy_stage_requirements.supporting_record_required IS
    'Whether a terminal result for this stage must cite at least one supporting record before an ALLOW decision may be finalized.';

-- ---------------------------------------------------------------------------
-- Typed authorization and lease-request Decision Record fields
-- ---------------------------------------------------------------------------

ALTER TABLE decision.decision_records
    ADD COLUMN expected_authorization_policy_version_id uuid
        REFERENCES access_control.authorization_policy_versions(
            authorization_policy_version_id
        ),
    ADD COLUMN requested_lease_lifetime interval,
    ADD COLUMN requested_use_mode text,
    ADD COLUMN requested_usage_limit integer,
    ADD COLUMN lease_audience text,
    ADD CONSTRAINT decision_records_lease_request_shape_ck
        CHECK (
            (
                decision_class IN ('LEASE_ISSUANCE', 'LEASE_RENEWAL')
                AND requester_identity_id IS NOT NULL
                AND session_id IS NOT NULL
                AND service_id IS NOT NULL
                AND requested_lease_lifetime IS NOT NULL
                AND requested_lease_lifetime > interval '0 seconds'
                AND requested_use_mode IS NOT NULL
                AND requested_use_mode IN (
                    'REUSABLE',
                    'SINGLE_USE',
                    'LIMITED_USE'
                )
                AND (
                    (
                        requested_use_mode = 'REUSABLE'
                        AND requested_usage_limit IS NULL
                    )
                    OR
                    (
                        requested_use_mode = 'SINGLE_USE'
                        AND requested_usage_limit = 1
                    )
                    OR
                    (
                        requested_use_mode = 'LIMITED_USE'
                        AND requested_usage_limit IS NOT NULL
                        AND requested_usage_limit > 1
                    )
                )
                AND lease_audience IS NOT NULL
                AND btrim(lease_audience) <> ''
            )
            OR
            (
                decision_class NOT IN ('LEASE_ISSUANCE', 'LEASE_RENEWAL')
                AND requested_lease_lifetime IS NULL
                AND requested_use_mode IS NULL
                AND requested_usage_limit IS NULL
                AND lease_audience IS NULL
            )
        ),
    ADD CONSTRAINT decision_records_decision_policy_uq
        UNIQUE (decision_id, authorization_policy_version_id),
    ADD CONSTRAINT decision_records_core_lease_context_uq
        UNIQUE (
            decision_id,
            request_id,
            correlation_id,
            requester_identity_id,
            session_id,
            service_id,
            operation_definition_id,
            authorization_policy_version_id
        );

COMMENT ON COLUMN
    decision.decision_records.expected_authorization_policy_version_id IS
    'Optional caller expectation that PostgreSQL must independently confirm as the unique applicable policy version.';

COMMENT ON COLUMN decision.decision_records.requested_lease_lifetime IS
    'Requested lifetime only. Controlled issuance must bound it to policy, session, authority, eligibility, approval, participation, and security limits.';

COMMENT ON COLUMN decision.decision_records.lease_audience IS
    'Requested exact protected consumer audience for a lease-issuance or lease-renewal decision.';

CREATE INDEX decision_records_phase3_request_idx
    ON decision.decision_records(
        decision_class,
        expected_authorization_policy_version_id,
        requester_identity_id,
        requester_organization_id,
        session_id,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        governed_scope_id,
        record_status,
        requested_at
    );

-- ---------------------------------------------------------------------------
-- Exact evaluation-to-policy-stage mapping
-- ---------------------------------------------------------------------------

ALTER TABLE decision.evaluation_records
    ADD COLUMN authorization_policy_version_id uuid,
    ADD COLUMN authorization_policy_stage_requirement_id uuid,
    ADD COLUMN policy_rule_reference text,
    ADD CONSTRAINT evaluation_records_policy_mapping_pair_ck
        CHECK (
            (
                authorization_policy_version_id IS NULL
                AND authorization_policy_stage_requirement_id IS NULL
            )
            OR
            (
                authorization_policy_version_id IS NOT NULL
                AND authorization_policy_stage_requirement_id IS NOT NULL
            )
        ),
    ADD CONSTRAINT evaluation_records_policy_rule_reference_ck
        CHECK (
            policy_rule_reference IS NULL
            OR btrim(policy_rule_reference) <> ''
        ),
    ADD CONSTRAINT evaluation_records_not_required_rule_ck
        CHECK (
            result <> 'NOT_REQUIRED'
            OR (
                NOT required
                AND authorization_policy_stage_requirement_id IS NOT NULL
                AND policy_rule_reference IS NOT NULL
            )
        ),
    ADD CONSTRAINT evaluation_records_decision_policy_fk
        FOREIGN KEY (decision_id, authorization_policy_version_id)
        REFERENCES decision.decision_records(
            decision_id,
            authorization_policy_version_id
        ),
    ADD CONSTRAINT evaluation_records_stage_requirement_fk
        FOREIGN KEY (
            authorization_policy_stage_requirement_id,
            authorization_policy_version_id,
            evaluation_order,
            evaluation_key,
            required
        )
        REFERENCES access_control.authorization_policy_stage_requirements(
            authorization_policy_stage_requirement_id,
            authorization_policy_version_id,
            stage_order,
            stage_key,
            required
        ),
    ADD CONSTRAINT evaluation_records_id_decision_uq
        UNIQUE (evaluation_id, decision_id);

COMMENT ON COLUMN
    decision.evaluation_records.authorization_policy_stage_requirement_id IS
    'Exact policy-stage requirement governing this evaluation. Bootstrap request-context and policy-selection evaluations may remain unbound.';

COMMENT ON COLUMN decision.evaluation_records.policy_rule_reference IS
    'Exact selected policy rule used by this result. It is required for NOT_REQUIRED.';

CREATE INDEX evaluation_records_policy_stage_idx
    ON decision.evaluation_records(
        authorization_policy_version_id,
        authorization_policy_stage_requirement_id,
        decision_id,
        evaluation_order
    );

ALTER TABLE decision.supporting_records
    ADD COLUMN required_for_result boolean
        NOT NULL DEFAULT true;

CREATE UNIQUE INDEX supporting_records_evidence_identity_uq
    ON decision.supporting_records(
        evaluation_id,
        record_type,
        record_id,
        COALESCE(record_version, '')
    );

-- ---------------------------------------------------------------------------
-- Authorization Lease typed bindings, chronology, and terminal-state shape
-- ---------------------------------------------------------------------------

ALTER TABLE access_control.authorization_leases
    ADD COLUMN not_before timestamptz,
    ADD COLUMN lease_audience text,
    ADD COLUMN expired_at timestamptz;

ALTER TABLE access_control.authorization_leases
    ALTER COLUMN issuing_decision_id SET NOT NULL,
    ALTER COLUMN service_id SET NOT NULL,
    ALTER COLUMN operation_definition_id SET NOT NULL,
    ALTER COLUMN not_before SET NOT NULL,
    ALTER COLUMN lease_audience SET NOT NULL,
    ADD CONSTRAINT authorization_leases_scope_reference_retired_ck
        CHECK (scope_reference IS NULL),
    ADD CONSTRAINT authorization_leases_audience_ck
        CHECK (btrim(lease_audience) <> ''),
    ADD CONSTRAINT authorization_leases_chronology_ck
        CHECK (
            not_before >= issued_at
            AND not_before < expires_at
            AND (
                consumed_at IS NULL
                OR (
                    consumed_at >= not_before
                    AND consumed_at < expires_at
                )
            )
            AND (
                revoked_at IS NULL
                OR revoked_at >= issued_at
            )
            AND (
                expired_at IS NULL
                OR expired_at >= expires_at
            )
        ),
    ADD CONSTRAINT authorization_leases_state_shape_ck
        CHECK (
            (
                status = 'ACTIVE'
                AND consumed_at IS NULL
                AND revoked_at IS NULL
                AND expired_at IS NULL
            )
            OR
            (
                status = 'CONSUMED'
                AND consumed_at IS NOT NULL
                AND revoked_at IS NULL
                AND expired_at IS NULL
                AND use_mode IN ('SINGLE_USE', 'LIMITED_USE')
                AND usage_limit IS NOT NULL
                AND successful_use_count = usage_limit
            )
            OR
            (
                status = 'REVOKED'
                AND consumed_at IS NULL
                AND revoked_at IS NOT NULL
                AND expired_at IS NULL
            )
            OR
            (
                status = 'EXPIRED'
                AND consumed_at IS NULL
                AND revoked_at IS NULL
                AND expired_at IS NOT NULL
            )
        ),
    ADD CONSTRAINT authorization_leases_revocation_reason_ck
        CHECK (
            (
                status = 'REVOKED'
                AND revocation_reason IS NOT NULL
                AND btrim(revocation_reason) <> ''
            )
            OR
            (
                status <> 'REVOKED'
                AND revocation_reason IS NULL
            )
        ),
    ADD CONSTRAINT authorization_leases_issuing_decision_uq
        UNIQUE (issuing_decision_id),
    ADD CONSTRAINT authorization_leases_id_decision_uq
        UNIQUE (authorization_lease_id, issuing_decision_id),
    ADD CONSTRAINT authorization_leases_decision_context_fk
        FOREIGN KEY (
            issuing_decision_id,
            request_id,
            correlation_id,
            identity_id,
            session_id,
            service_id,
            operation_definition_id,
            authorization_policy_version_id
        )
        REFERENCES decision.decision_records(
            decision_id,
            request_id,
            correlation_id,
            requester_identity_id,
            session_id,
            service_id,
            operation_definition_id,
            authorization_policy_version_id
        );

COMMENT ON COLUMN access_control.authorization_leases.not_before IS
    'Authoritative earliest usability time. Controlled issuance must set it from PostgreSQL time and keep it before expires_at.';

COMMENT ON COLUMN access_control.authorization_leases.lease_audience IS
    'Exact protected consumer audience bound to this lease.';

COMMENT ON COLUMN access_control.authorization_leases.expired_at IS
    'Materialized expiration transition time. PostgreSQL time can make a lease unusable before this field is populated.';

CREATE UNIQUE INDEX decision_records_authorization_lease_uq
    ON decision.decision_records(authorization_lease_id)
    WHERE authorization_lease_id IS NOT NULL
      AND decision_class IN ('LEASE_ISSUANCE', 'LEASE_RENEWAL');

CREATE INDEX decision_records_authorization_lease_reference_idx
    ON decision.decision_records(authorization_lease_id, decision_class)
    WHERE authorization_lease_id IS NOT NULL;

CREATE INDEX authorization_leases_phase3_context_idx
    ON access_control.authorization_leases(
        issuing_decision_id,
        identity_id,
        requester_organization_id,
        session_id,
        device_id,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        governed_scope_id,
        authorization_policy_version_id,
        status,
        not_before,
        expires_at
    );

-- ---------------------------------------------------------------------------
-- Lease authority evidence and use-event Decision Record binding
-- ---------------------------------------------------------------------------

ALTER TABLE access_control.lease_authority_grants
    ADD COLUMN decision_id uuid,
    ADD COLUMN evaluation_id uuid;

ALTER TABLE access_control.lease_authority_grants
    ALTER COLUMN decision_id SET NOT NULL,
    ALTER COLUMN evaluation_id SET NOT NULL,
    ADD CONSTRAINT lease_authority_grants_decision_fk
        FOREIGN KEY (decision_id)
        REFERENCES decision.decision_records(decision_id),
    ADD CONSTRAINT lease_authority_grants_lease_decision_fk
        FOREIGN KEY (authorization_lease_id, decision_id)
        REFERENCES access_control.authorization_leases(
            authorization_lease_id,
            issuing_decision_id
        ),
    ADD CONSTRAINT lease_authority_grants_evaluation_decision_fk
        FOREIGN KEY (evaluation_id, decision_id)
        REFERENCES decision.evaluation_records(
            evaluation_id,
            decision_id
        );

COMMENT ON COLUMN access_control.lease_authority_grants.evaluation_id IS
    'Exact AUTHORITY evaluation record that cited this grant for the issuing decision.';

ALTER TABLE access_control.authorization_lease_use_events
    ALTER COLUMN decision_reference SET NOT NULL,
    ADD CONSTRAINT authorization_lease_use_events_decision_fk
        FOREIGN KEY (decision_reference)
        REFERENCES decision.decision_records(decision_id);

CREATE INDEX authorization_lease_use_events_decision_idx
    ON access_control.authorization_lease_use_events(
        decision_reference,
        authorization_lease_id,
        used_at
    );


-- ---------------------------------------------------------------------------
-- Phase 3 Step 3 deterministic policy selection and decision finalization
-- ---------------------------------------------------------------------------

CREATE FUNCTION decision.resolve_authorization_policy(
    p_decision_id uuid
)
RETURNS TABLE (
    authorization_policy_version_id uuid,
    resolution_code text
)
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog, decision, access_control
AS $function$
DECLARE
    v_decision decision.decision_records%ROWTYPE;
    v_candidate_count bigint;
    v_selected_policy_id uuid;
BEGIN
    SELECT decision_record.*
    INTO v_decision
    FROM decision.decision_records AS decision_record
    WHERE decision_record.decision_id = p_decision_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'no_data_found',
                MESSAGE = 'Authorization Decision Record does not exist';
    END IF;

    WITH applicable_policy AS (
        SELECT
            policy_version.authorization_policy_version_id,
            policy_version.selection_priority,
            (
                CASE WHEN policy_version.service_id IS NOT NULL THEN 1 ELSE 0 END
                + CASE
                    WHEN policy_version.purpose_definition_id IS NOT NULL
                    THEN 1 ELSE 0
                  END
                + CASE
                    WHEN policy_version.operation_definition_id IS NOT NULL
                    THEN 1 ELSE 0
                  END
                + CASE
                    WHEN policy_version.requester_organization_id IS NOT NULL
                    THEN 1 ELSE 0
                  END
                + CASE
                    WHEN policy_version.governed_scope_id IS NOT NULL
                    THEN 1 ELSE 0
                  END
                + CASE
                    WHEN policy_version.protected_target_type IS NOT NULL
                    THEN 2 ELSE 0
                  END
                + CASE
                    WHEN policy_version.classification_key IS NOT NULL
                    THEN 1 ELSE 0
                  END
                + CASE
                    WHEN policy_version.lease_audience IS NOT NULL
                    THEN 1 ELSE 0
                  END
            ) AS specificity
        FROM access_control.authorization_policy_versions AS policy_version
        JOIN access_control.authorization_policies AS policy
          ON policy.authorization_policy_id =
             policy_version.authorization_policy_id
        WHERE policy.status = 'ACTIVE'
          AND policy_version.status = 'ACTIVE'
          AND policy_version.valid_from <= v_decision.evaluated_at
          AND (
              policy_version.valid_until IS NULL
              OR policy_version.valid_until > v_decision.evaluated_at
          )
          AND policy_version.decision_class = v_decision.decision_class
          AND (
              policy_version.service_id IS NULL
              OR policy_version.service_id IS NOT DISTINCT FROM
                 v_decision.service_id
          )
          AND (
              policy_version.purpose_definition_id IS NULL
              OR policy_version.purpose_definition_id IS NOT DISTINCT FROM
                 v_decision.purpose_definition_id
          )
          AND (
              policy_version.operation_definition_id IS NULL
              OR policy_version.operation_definition_id =
                 v_decision.operation_definition_id
          )
          AND (
              policy_version.requester_organization_id IS NULL
              OR policy_version.requester_organization_id IS NOT DISTINCT FROM
                 v_decision.requester_organization_id
          )
          AND (
              policy_version.applies_to_all_governed_scopes
              OR policy_version.governed_scope_id IS NOT DISTINCT FROM
                 v_decision.governed_scope_id
          )
          AND (
              policy_version.applies_to_all_targets
              OR (
                  policy_version.protected_target_type =
                      v_decision.protected_target_type
                  AND policy_version.protected_target_reference =
                      v_decision.protected_target_reference
              )
              OR (
                  NOT policy_version.protected_target_required
                  AND policy_version.protected_target_type IS NULL
              )
          )
          AND (
              policy_version.classification_key IS NULL
              OR policy_version.classification_key IS NOT DISTINCT FROM
                 v_decision.classification_key
          )
          AND (
              policy_version.lease_audience IS NULL
              OR policy_version.lease_audience IS NOT DISTINCT FROM
                 v_decision.lease_audience
          )
    ),
    highest_specificity AS (
        SELECT max(applicable_policy.specificity) AS specificity
        FROM applicable_policy
    ),
    highest_precedence AS (
        SELECT min(applicable_policy.selection_priority) AS selection_priority
        FROM applicable_policy
        JOIN highest_specificity
          ON highest_specificity.specificity =
             applicable_policy.specificity
    ),
    winning_candidate AS (
        SELECT applicable_policy.authorization_policy_version_id
        FROM applicable_policy
        JOIN highest_specificity
          ON highest_specificity.specificity =
             applicable_policy.specificity
        JOIN highest_precedence
          ON highest_precedence.selection_priority =
             applicable_policy.selection_priority
    )
    SELECT
        count(*),
        (array_agg(
            winning_candidate.authorization_policy_version_id
            ORDER BY
                winning_candidate.authorization_policy_version_id::text
        ))[1]
    INTO
        v_candidate_count,
        v_selected_policy_id
    FROM winning_candidate;

    IF v_candidate_count = 0 THEN
        authorization_policy_version_id := NULL;
        resolution_code := 'AUTHORIZATION_POLICY_NOT_FOUND';
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_candidate_count > 1 THEN
        authorization_policy_version_id := NULL;
        resolution_code := 'AUTHORIZATION_POLICY_AMBIGUOUS';
        RETURN NEXT;
        RETURN;
    END IF;

    authorization_policy_version_id := v_selected_policy_id;
    resolution_code := 'AUTHORIZATION_POLICY_SELECTED';
    RETURN NEXT;
END;
$function$;

COMMENT ON FUNCTION decision.resolve_authorization_policy(uuid) IS
    'Resolve one uniquely applicable Authorization Policy Version using exact request context, explicit specificity, and selection priority. Returns a stable policy-resolution code and never uses physical row order as authority.';

REVOKE ALL ON FUNCTION decision.resolve_authorization_policy(uuid)
    FROM PUBLIC;

CREATE FUNCTION decision.bind_authorization_policy(
    p_decision_id uuid
)
RETURNS text
LANGUAGE plpgsql
SET search_path = pg_catalog, decision, access_control
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_decision decision.decision_records%ROWTYPE;
    v_selected_policy_id uuid;
    v_resolution_code text;
BEGIN
    SELECT decision_record.*
    INTO v_decision
    FROM decision.decision_records AS decision_record
    WHERE decision_record.decision_id = p_decision_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'no_data_found',
                MESSAGE = 'Authorization Decision Record does not exist';
    END IF;

    IF v_decision.record_status <> 'DRAFT' THEN
        RETURN 'AUTHORIZATION_DECISION_ALREADY_FINALIZED';
    END IF;

    IF v_decision.authorization_policy_version_id IS NOT NULL THEN
        RETURN 'AUTHORIZATION_POLICY_ALREADY_BOUND';
    END IF;

    SELECT
        resolution.authorization_policy_version_id,
        resolution.resolution_code
    INTO
        v_selected_policy_id,
        v_resolution_code
    FROM decision.resolve_authorization_policy(p_decision_id) AS resolution;

    IF v_resolution_code IN (
        'AUTHORIZATION_POLICY_NOT_FOUND',
        'AUTHORIZATION_POLICY_AMBIGUOUS'
    ) THEN
        UPDATE decision.decision_records
        SET
            record_status = 'FINALIZED',
            final_result = 'DENY',
            primary_reason_code = v_resolution_code,
            finalized_at = v_now
        WHERE decision_id = p_decision_id;

        RETURN v_resolution_code;
    END IF;

    IF (
        v_decision.expected_authorization_policy_version_id IS NOT NULL
        AND v_decision.expected_authorization_policy_version_id <>
            v_selected_policy_id
    ) THEN
        UPDATE decision.decision_records
        SET
            record_status = 'FINALIZED',
            final_result = 'DENY',
            primary_reason_code =
                'AUTHORIZATION_POLICY_CONTEXT_MISMATCH',
            finalized_at = v_now
        WHERE decision_id = p_decision_id;

        RETURN 'AUTHORIZATION_POLICY_CONTEXT_MISMATCH';
    END IF;

    UPDATE decision.decision_records
    SET authorization_policy_version_id = v_selected_policy_id
    WHERE decision_id = p_decision_id
      AND record_status = 'DRAFT'
      AND authorization_policy_version_id IS NULL;

    IF NOT FOUND THEN
        RETURN 'AUTHORIZATION_DECISION_ALREADY_FINALIZED';
    END IF;

    RETURN 'AUTHORIZATION_POLICY_SELECTED';
END;
$function$;

COMMENT ON FUNCTION decision.bind_authorization_policy(uuid) IS
    'Lock one draft Decision Record, resolve and bind its unique applicable Authorization Policy Version, or persist a terminal DENY for missing, ambiguous, or mismatched policy context.';

REVOKE ALL ON FUNCTION decision.bind_authorization_policy(uuid)
    FROM PUBLIC;

CREATE FUNCTION decision.finalize_authorization_decision(
    p_decision_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, decision, access_control
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_decision decision.decision_records%ROWTYPE;
    v_bind_result text;
    v_reason_code text;
BEGIN
    SELECT decision_record.*
    INTO v_decision
    FROM decision.decision_records AS decision_record
    WHERE decision_record.decision_id = p_decision_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'no_data_found',
                MESSAGE = 'Authorization Decision Record does not exist';
    END IF;

    IF v_decision.record_status <> 'DRAFT' THEN
        RETURN false;
    END IF;

    IF v_decision.authorization_policy_version_id IS NULL THEN
        v_bind_result :=
            decision.bind_authorization_policy(p_decision_id);

        IF v_bind_result <> 'AUTHORIZATION_POLICY_SELECTED' THEN
            RETURN true;
        END IF;

        SELECT decision_record.*
        INTO v_decision
        FROM decision.decision_records AS decision_record
        WHERE decision_record.decision_id = p_decision_id
        FOR UPDATE;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM access_control.authorization_policy_stage_requirements
            AS stage_requirement
        WHERE stage_requirement.authorization_policy_version_id =
              v_decision.authorization_policy_version_id
          AND NOT EXISTS (
              SELECT 1
              FROM decision.evaluation_records AS evaluation
              WHERE evaluation.decision_id = p_decision_id
                AND evaluation.authorization_policy_stage_requirement_id =
                    stage_requirement.authorization_policy_stage_requirement_id
          )
    ) THEN
        v_reason_code := 'AUTHORIZATION_DECISION_INCOMPLETE';

    ELSIF EXISTS (
        SELECT 1
        FROM access_control.authorization_policy_stage_requirements
            AS stage_requirement
        JOIN decision.evaluation_records AS evaluation
          ON evaluation.decision_id = p_decision_id
         AND evaluation.authorization_policy_stage_requirement_id =
             stage_requirement.authorization_policy_stage_requirement_id
        WHERE stage_requirement.authorization_policy_version_id =
              v_decision.authorization_policy_version_id
          AND stage_requirement.required
          AND evaluation.result = 'FAIL'
    ) THEN
        v_reason_code :=
            'AUTHORIZATION_DECISION_REQUIRED_STAGE_FAILED';

    ELSIF EXISTS (
        SELECT 1
        FROM access_control.authorization_policy_stage_requirements
            AS stage_requirement
        JOIN decision.evaluation_records AS evaluation
          ON evaluation.decision_id = p_decision_id
         AND evaluation.authorization_policy_stage_requirement_id =
             stage_requirement.authorization_policy_stage_requirement_id
        WHERE stage_requirement.authorization_policy_version_id =
              v_decision.authorization_policy_version_id
          AND stage_requirement.required
          AND evaluation.result = 'NOT_EVALUATED'
    ) THEN
        v_reason_code :=
            'AUTHORIZATION_DECISION_REQUIRED_STAGE_NOT_EVALUATED';

    ELSIF EXISTS (
        SELECT 1
        FROM access_control.authorization_policy_stage_requirements
            AS stage_requirement
        JOIN decision.evaluation_records AS evaluation
          ON evaluation.decision_id = p_decision_id
         AND evaluation.authorization_policy_stage_requirement_id =
             stage_requirement.authorization_policy_stage_requirement_id
        WHERE stage_requirement.authorization_policy_version_id =
              v_decision.authorization_policy_version_id
          AND evaluation.result = 'NOT_REQUIRED'
          AND (
              stage_requirement.required
              OR evaluation.reason_code <>
                 stage_requirement.not_required_reason_code
              OR evaluation.policy_rule_reference <>
                 stage_requirement.not_required_rule_reference
          )
    ) THEN
        v_reason_code :=
            'AUTHORIZATION_DECISION_NOT_REQUIRED_RULE_MISSING';

    ELSIF EXISTS (
        SELECT 1
        FROM access_control.authorization_policy_stage_requirements
            AS stage_requirement
        JOIN decision.evaluation_records AS evaluation
          ON evaluation.decision_id = p_decision_id
         AND evaluation.authorization_policy_stage_requirement_id =
             stage_requirement.authorization_policy_stage_requirement_id
        WHERE stage_requirement.authorization_policy_version_id =
              v_decision.authorization_policy_version_id
          AND stage_requirement.supporting_record_required
          AND NOT EXISTS (
              SELECT 1
              FROM decision.supporting_records AS supporting_record
              WHERE supporting_record.evaluation_id =
                    evaluation.evaluation_id
                AND supporting_record.required_for_result
          )
    ) THEN
        v_reason_code := 'AUTHORIZATION_DECISION_INCOMPLETE';

    ELSIF EXISTS (
        SELECT 1
        FROM decision.evaluation_records AS evaluation
        WHERE evaluation.decision_id = p_decision_id
          AND evaluation.result = 'FAIL'
    ) THEN
        v_reason_code :=
            'AUTHORIZATION_DECISION_REQUIRED_STAGE_FAILED';

    ELSIF EXISTS (
        SELECT 1
        FROM decision.evaluation_records AS evaluation
        WHERE evaluation.decision_id = p_decision_id
          AND evaluation.result = 'NOT_EVALUATED'
    ) THEN
        v_reason_code :=
            'AUTHORIZATION_DECISION_REQUIRED_STAGE_NOT_EVALUATED';
    END IF;

    IF v_reason_code IS NULL THEN
        UPDATE decision.decision_records
        SET
            record_status = 'FINALIZED',
            final_result = 'ALLOW',
            primary_reason_code = 'AUTHORIZATION_DECISION_ALLOWED',
            finalized_at = v_now
        WHERE decision_id = p_decision_id
          AND record_status = 'DRAFT';
    ELSE
        UPDATE decision.decision_records
        SET
            record_status = 'FINALIZED',
            final_result = 'DENY',
            primary_reason_code = v_reason_code,
            finalized_at = v_now
        WHERE decision_id = p_decision_id
          AND record_status = 'DRAFT';
    END IF;

    RETURN FOUND;
END;
$function$;

COMMENT ON FUNCTION decision.finalize_authorization_decision(uuid) IS
    'Finalize one draft authorization Decision Record exactly once. The function binds a unique applicable policy when necessary, requires complete policy-stage closure, validates NOT_REQUIRED rules and required supporting evidence, and computes ALLOW or DENY without accepting a caller-supplied result.';

REVOKE ALL ON FUNCTION decision.finalize_authorization_decision(uuid)
    FROM PUBLIC;

CREATE OR REPLACE FUNCTION decision.finalize_decision(
    p_decision_id uuid,
    p_final_result text,
    p_primary_reason_code text
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, decision
AS $function$
DECLARE
    v_finalized boolean;
    v_actual_result text;
    v_actual_reason_code text;
BEGIN
    v_finalized :=
        decision.finalize_authorization_decision(p_decision_id);

    SELECT
        decision_record.final_result,
        decision_record.primary_reason_code
    INTO
        v_actual_result,
        v_actual_reason_code
    FROM decision.decision_records AS decision_record
    WHERE decision_record.decision_id = p_decision_id;

    IF p_final_result IS DISTINCT FROM v_actual_result
       OR p_primary_reason_code IS DISTINCT FROM v_actual_reason_code
    THEN
        RAISE EXCEPTION
            USING
                ERRCODE = 'check_violation',
                MESSAGE =
                    'Caller-supplied decision result does not match the authoritative computed result';
    END IF;

    RETURN v_finalized;
END;
$function$;

COMMENT ON FUNCTION decision.finalize_decision(uuid, text, text) IS
    'Compatibility wrapper that computes the authoritative result through finalize_authorization_decision and rejects caller-supplied values that do not exactly match the persisted result. Caller input is never the authority source.';

REVOKE ALL ON FUNCTION decision.finalize_decision(uuid, text, text)
    FROM PUBLIC;


-- ---------------------------------------------------------------------------
-- Phase 3 Step 4 controlled Authorization Lease issuance and use
-- ---------------------------------------------------------------------------

CREATE FUNCTION access_control.issue_authorization_lease_from_decision(
    p_decision_id uuid,
    p_plaintext_secret text
)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control, decision
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_decision decision.decision_records%ROWTYPE;
    v_session access_control.sessions%ROWTYPE;
    v_policy access_control.authorization_policy_versions%ROWTYPE;
    v_environment_key text;
    v_lease_id uuid := pg_catalog.gen_random_uuid();
    v_expires_at timestamptz;
    v_supporting_evidence_expires_at timestamptz;
    v_authority_expires_at timestamptz;
BEGIN
    IF p_decision_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Decision identifier must not be null';
    END IF;

    IF p_plaintext_secret IS NULL
       OR pg_catalog.octet_length(p_plaintext_secret) < 32
    THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Authorization Lease secret must contain at least 32 bytes';
    END IF;

    SELECT decision_record.*
    INTO v_decision
    FROM decision.decision_records AS decision_record
    WHERE decision_record.decision_id = p_decision_id
    FOR UPDATE;

    IF NOT FOUND
       OR v_decision.record_status <> 'FINALIZED'
       OR v_decision.final_result <> 'ALLOW'
       OR v_decision.decision_class NOT IN ('LEASE_ISSUANCE', 'LEASE_RENEWAL')
       OR v_decision.authorization_policy_version_id IS NULL
       OR v_decision.authorization_lease_id IS NOT NULL
    THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_authorization_specification',
            MESSAGE = 'Authorization Lease issuance is unavailable';
    END IF;

    SELECT session_record.*
    INTO v_session
    FROM access_control.sessions AS session_record
    WHERE session_record.session_id = v_decision.session_id
    FOR UPDATE;

    SELECT policy_version.*
    INTO v_policy
    FROM access_control.authorization_policy_versions AS policy_version
    WHERE policy_version.authorization_policy_version_id =
          v_decision.authorization_policy_version_id
    FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_authorization_specification',
            MESSAGE = 'Authorization Lease issuance is unavailable';
    END IF;

    SELECT provider_record.environment_key
    INTO v_environment_key
    FROM trust.trust_providers AS provider_record
    WHERE provider_record.trust_provider_id = v_session.trust_provider_id;

    IF v_session.status <> 'ACTIVE'
       OR v_now < v_session.authenticated_at
       OR v_now >= v_session.expires_at
       OR (
           v_session.inactivity_timeout IS NOT NULL
           AND v_now >= COALESCE(
               v_session.last_activity_at,
               v_session.authenticated_at
           ) + v_session.inactivity_timeout
       )
       OR v_session.identity_id <> v_decision.requester_identity_id
       OR v_session.organization_id IS DISTINCT FROM
          v_decision.requester_organization_id
       OR v_session.device_id IS DISTINCT FROM v_decision.device_id
       OR v_session.service_id IS DISTINCT FROM v_decision.service_id
       OR NOT access_control.session_context_is_locally_usable(
           v_session.identity_id,
           v_session.device_id,
           v_session.trust_provider_id,
           v_session.service_id,
           v_session.organization_id,
           v_environment_key,
           v_now
       )
    THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_authorization_specification',
            MESSAGE = 'Authorization Lease issuance is unavailable';
    END IF;

    IF v_policy.status <> 'ACTIVE'
       OR v_policy.valid_from > v_now
       OR (v_policy.valid_until IS NOT NULL AND v_now >= v_policy.valid_until)
       OR v_policy.lease_audience IS NULL
       OR v_decision.requested_lease_lifetime > v_policy.lease_lifetime
       OR v_decision.requested_use_mode <> v_policy.lease_use_mode
       OR v_decision.requested_usage_limit IS DISTINCT FROM
          v_policy.lease_usage_limit
       OR v_policy.lease_audience <> v_decision.lease_audience
    THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_authorization_specification',
            MESSAGE = 'Authorization Lease issuance is unavailable';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM decision.evaluation_records AS evaluation
        JOIN decision.supporting_records AS supporting
          ON supporting.evaluation_id = evaluation.evaluation_id
        WHERE evaluation.decision_id = v_decision.decision_id
          AND supporting.required_for_result
          AND (
              (
                  supporting.effective_from IS NOT NULL
                  AND supporting.effective_from > v_now
              )
              OR (
                  supporting.effective_until IS NOT NULL
                  AND v_now >= supporting.effective_until
              )
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_authorization_specification',
            MESSAGE = 'Authorization Lease issuance is unavailable';
    END IF;

    SELECT pg_catalog.min(supporting.effective_until)
    INTO v_supporting_evidence_expires_at
    FROM decision.evaluation_records AS evaluation
    JOIN decision.supporting_records AS supporting
      ON supporting.evaluation_id = evaluation.evaluation_id
    WHERE evaluation.decision_id = v_decision.decision_id
      AND supporting.required_for_result
      AND supporting.effective_until IS NOT NULL;

    IF EXISTS (
        SELECT 1
        FROM access_control.authorization_policy_stage_requirements AS stage
        WHERE stage.authorization_policy_version_id =
              v_decision.authorization_policy_version_id
          AND stage.stage_key = 'AUTHORITY'
          AND stage.required
          AND NOT EXISTS (
              SELECT 1
              FROM decision.evaluation_records AS evaluation
              JOIN decision.supporting_records AS supporting
                ON supporting.evaluation_id = evaluation.evaluation_id
              JOIN access_control.authority_grants AS authority_grant
                ON authority_grant.authority_grant_id::text =
                   supporting.record_id
              WHERE evaluation.decision_id = v_decision.decision_id
                AND evaluation.evaluation_key = 'AUTHORITY'
                AND evaluation.result = 'PASS'
                AND supporting.record_type = 'AUTHORITY_GRANT'
                AND supporting.required_for_result
                AND authority_grant.identity_id =
                    v_decision.requester_identity_id
                AND authority_grant.status = 'ACTIVE'
                AND authority_grant.valid_from <= v_now
                AND (
                    authority_grant.valid_until IS NULL
                    OR v_now < authority_grant.valid_until
                )
                AND (
                    authority_grant.service_id IS NULL
                    OR authority_grant.service_id = v_decision.service_id
                )
                AND (
                    authority_grant.purpose_definition_id IS NULL
                    OR authority_grant.purpose_definition_id =
                       v_decision.purpose_definition_id
                )
                AND (
                    authority_grant.operation_definition_id IS NULL
                    OR authority_grant.operation_definition_id =
                       v_decision.operation_definition_id
                )
                AND (
                    authority_grant.organization_id IS NULL
                    OR authority_grant.organization_id =
                       v_decision.requester_organization_id
                )
                AND authority_grant.scope_reference IS NULL
                AND (
                    authority_grant.applies_to_all_governed_scopes
                    OR authority_grant.governed_scope_id IS NOT DISTINCT FROM
                       v_decision.governed_scope_id
                )
                AND (
                    authority_grant.applies_to_all_targets
                    OR (
                        authority_grant.protected_target_type IS NOT DISTINCT FROM
                            v_decision.protected_target_type
                        AND authority_grant.protected_target_reference IS NOT DISTINCT FROM
                            v_decision.protected_target_reference
                    )
                )
          )
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_authorization_specification',
            MESSAGE = 'Authorization Lease issuance is unavailable';
    END IF;

    SELECT pg_catalog.min(authority_grant.valid_until)
    INTO v_authority_expires_at
    FROM decision.evaluation_records AS evaluation
    JOIN decision.supporting_records AS supporting
      ON supporting.evaluation_id = evaluation.evaluation_id
    JOIN access_control.authority_grants AS authority_grant
      ON authority_grant.authority_grant_id::text = supporting.record_id
    WHERE evaluation.decision_id = v_decision.decision_id
      AND evaluation.evaluation_key = 'AUTHORITY'
      AND evaluation.result = 'PASS'
      AND supporting.record_type = 'AUTHORITY_GRANT'
      AND supporting.required_for_result
      AND authority_grant.identity_id = v_decision.requester_identity_id
      AND authority_grant.status = 'ACTIVE'
      AND authority_grant.valid_from <= v_now
      AND (authority_grant.valid_until IS NULL OR v_now < authority_grant.valid_until)
      AND (authority_grant.service_id IS NULL OR authority_grant.service_id = v_decision.service_id)
      AND (
          authority_grant.purpose_definition_id IS NULL
          OR authority_grant.purpose_definition_id = v_decision.purpose_definition_id
      )
      AND (
          authority_grant.operation_definition_id IS NULL
          OR authority_grant.operation_definition_id = v_decision.operation_definition_id
      )
      AND (
          authority_grant.organization_id IS NULL
          OR authority_grant.organization_id = v_decision.requester_organization_id
      )
      AND authority_grant.scope_reference IS NULL
      AND (
          authority_grant.applies_to_all_governed_scopes
          OR authority_grant.governed_scope_id IS NOT DISTINCT FROM
             v_decision.governed_scope_id
      )
      AND (
          authority_grant.applies_to_all_targets
          OR (
              authority_grant.protected_target_type IS NOT DISTINCT FROM
                  v_decision.protected_target_type
              AND authority_grant.protected_target_reference IS NOT DISTINCT FROM
                  v_decision.protected_target_reference
          )
      )
      AND authority_grant.valid_until IS NOT NULL;

    v_expires_at := LEAST(
        v_now + v_decision.requested_lease_lifetime,
        v_now + v_policy.lease_lifetime,
        v_session.expires_at,
        COALESCE(v_policy.valid_until, v_session.expires_at),
        COALESCE(v_supporting_evidence_expires_at, v_session.expires_at),
        COALESCE(v_authority_expires_at, v_session.expires_at)
    );

    IF v_expires_at <= v_now THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_authorization_specification',
            MESSAGE = 'Authorization Lease issuance is unavailable';
    END IF;

    INSERT INTO access_control.authorization_leases (
        authorization_lease_id,
        request_id,
        lease_secret_hash,
        session_id,
        identity_id,
        requester_organization_id,
        device_id,
        service_id,
        purpose_definition_id,
        operation_definition_id,
        protected_target_type,
        protected_target_reference,
        governed_scope_id,
        classification_key,
        authorization_policy_version_id,
        approval_request_id,
        issuing_decision_id,
        use_mode,
        usage_limit,
        successful_use_count,
        issued_at,
        not_before,
        expires_at,
        lease_audience,
        status,
        correlation_id
    ) VALUES (
        v_lease_id,
        v_decision.request_id,
        access_control.hash_lease_secret(p_plaintext_secret),
        v_decision.session_id,
        v_decision.requester_identity_id,
        v_decision.requester_organization_id,
        v_decision.device_id,
        v_decision.service_id,
        v_decision.purpose_definition_id,
        v_decision.operation_definition_id,
        v_decision.protected_target_type,
        v_decision.protected_target_reference,
        v_decision.governed_scope_id,
        v_decision.classification_key,
        v_decision.authorization_policy_version_id,
        v_decision.approval_request_id,
        v_decision.decision_id,
        v_decision.requested_use_mode,
        v_decision.requested_usage_limit,
        0,
        v_now,
        v_now,
        v_expires_at,
        v_decision.lease_audience,
        'ACTIVE',
        v_decision.correlation_id
    );

    INSERT INTO access_control.lease_authority_grants (
        authorization_lease_id,
        authority_grant_id,
        decision_id,
        evaluation_id
    )
    SELECT DISTINCT ON (authority_grant.authority_grant_id)
        v_lease_id,
        authority_grant.authority_grant_id,
        v_decision.decision_id,
        evaluation.evaluation_id
    FROM decision.evaluation_records AS evaluation
    JOIN decision.supporting_records AS supporting
      ON supporting.evaluation_id = evaluation.evaluation_id
    JOIN access_control.authority_grants AS authority_grant
      ON authority_grant.authority_grant_id::text = supporting.record_id
    WHERE evaluation.decision_id = v_decision.decision_id
      AND evaluation.evaluation_key = 'AUTHORITY'
      AND evaluation.result = 'PASS'
      AND supporting.record_type = 'AUTHORITY_GRANT'
      AND supporting.required_for_result
      AND authority_grant.identity_id = v_decision.requester_identity_id
      AND authority_grant.status = 'ACTIVE'
      AND authority_grant.valid_from <= v_now
      AND (authority_grant.valid_until IS NULL OR v_now < authority_grant.valid_until)
      AND (authority_grant.service_id IS NULL OR authority_grant.service_id = v_decision.service_id)
      AND (
          authority_grant.purpose_definition_id IS NULL
          OR authority_grant.purpose_definition_id = v_decision.purpose_definition_id
      )
      AND (
          authority_grant.operation_definition_id IS NULL
          OR authority_grant.operation_definition_id = v_decision.operation_definition_id
      )
      AND (
          authority_grant.organization_id IS NULL
          OR authority_grant.organization_id = v_decision.requester_organization_id
      )
      AND authority_grant.scope_reference IS NULL
      AND (
          authority_grant.applies_to_all_governed_scopes
          OR authority_grant.governed_scope_id IS NOT DISTINCT FROM
             v_decision.governed_scope_id
      )
      AND (
          authority_grant.applies_to_all_targets
          OR (
              authority_grant.protected_target_type IS NOT DISTINCT FROM
                  v_decision.protected_target_type
              AND authority_grant.protected_target_reference IS NOT DISTINCT FROM
                  v_decision.protected_target_reference
          )
      )
    ORDER BY
        authority_grant.authority_grant_id,
        evaluation.evaluation_order,
        evaluation.evaluation_id;

    UPDATE decision.decision_records
    SET authorization_lease_id = v_lease_id
    WHERE decision_id = v_decision.decision_id
      AND authorization_lease_id IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_authorization_specification',
            MESSAGE = 'Authorization Lease issuance is unavailable';
    END IF;

    RETURN v_lease_id;
END;
$function$;

COMMENT ON FUNCTION
    access_control.issue_authorization_lease_from_decision(uuid, text) IS
    'Issue exactly one short-lived Authorization Lease from one finalized ALLOW lease decision. PostgreSQL locks and revalidates the Decision Record, selected policy, required supporting evidence, linked authority, active session, current local trust, and bounded lifetime. The plaintext secret is never stored.';

REVOKE ALL ON FUNCTION
    access_control.issue_authorization_lease_from_decision(uuid, text)
    FROM PUBLIC;

CREATE FUNCTION access_control.authorization_lease_context_is_usable(
    p_authorization_lease_id uuid,
    p_plaintext_secret text,
    p_identity_id uuid,
    p_requester_organization_id uuid,
    p_session_id uuid,
    p_device_id uuid,
    p_service_id uuid,
    p_purpose_definition_id uuid,
    p_operation_definition_id uuid,
    p_protected_target_type text,
    p_protected_target_reference text,
    p_governed_scope_id uuid,
    p_classification_key text,
    p_authorization_policy_version_id uuid,
    p_lease_audience text
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, access_control, decision
AS $function$
    SELECT EXISTS (
        SELECT 1
        FROM access_control.authorization_leases AS lease
        JOIN decision.decision_records AS issuing_decision
          ON issuing_decision.decision_id = lease.issuing_decision_id
         AND issuing_decision.authorization_lease_id =
             lease.authorization_lease_id
        JOIN access_control.sessions AS session_record
          ON session_record.session_id = lease.session_id
        JOIN trust.trust_providers AS provider_record
          ON provider_record.trust_provider_id =
             session_record.trust_provider_id
        JOIN access_control.authorization_policy_versions AS policy_version
          ON policy_version.authorization_policy_version_id =
             lease.authorization_policy_version_id
        WHERE lease.authorization_lease_id = p_authorization_lease_id
          AND lease.status = 'ACTIVE'
          AND lease.consumed_at IS NULL
          AND lease.revoked_at IS NULL
          AND lease.expired_at IS NULL
          AND lease.not_before <= pg_catalog.statement_timestamp()
          AND pg_catalog.statement_timestamp() < lease.expires_at
          AND lease.lease_secret_hash =
              access_control.hash_lease_secret(p_plaintext_secret)
          AND lease.identity_id = p_identity_id
          AND lease.requester_organization_id IS NOT DISTINCT FROM
              p_requester_organization_id
          AND lease.session_id = p_session_id
          AND lease.device_id IS NOT DISTINCT FROM p_device_id
          AND lease.service_id IS NOT DISTINCT FROM p_service_id
          AND lease.purpose_definition_id IS NOT DISTINCT FROM
              p_purpose_definition_id
          AND lease.operation_definition_id = p_operation_definition_id
          AND lease.protected_target_type IS NOT DISTINCT FROM
              p_protected_target_type
          AND lease.protected_target_reference IS NOT DISTINCT FROM
              p_protected_target_reference
          AND lease.governed_scope_id IS NOT DISTINCT FROM
              p_governed_scope_id
          AND lease.classification_key IS NOT DISTINCT FROM
              p_classification_key
          AND lease.authorization_policy_version_id =
              p_authorization_policy_version_id
          AND lease.lease_audience = p_lease_audience
          AND issuing_decision.decision_class IN (
              'LEASE_ISSUANCE',
              'LEASE_RENEWAL'
          )
          AND issuing_decision.record_status = 'FINALIZED'
          AND issuing_decision.final_result = 'ALLOW'
          AND issuing_decision.requester_identity_id = lease.identity_id
          AND issuing_decision.requester_organization_id IS NOT DISTINCT FROM
              lease.requester_organization_id
          AND issuing_decision.session_id = lease.session_id
          AND issuing_decision.device_id IS NOT DISTINCT FROM lease.device_id
          AND issuing_decision.service_id = lease.service_id
          AND issuing_decision.purpose_definition_id IS NOT DISTINCT FROM
              lease.purpose_definition_id
          AND issuing_decision.operation_definition_id =
              lease.operation_definition_id
          AND issuing_decision.protected_target_type IS NOT DISTINCT FROM
              lease.protected_target_type
          AND issuing_decision.protected_target_reference IS NOT DISTINCT FROM
              lease.protected_target_reference
          AND issuing_decision.governed_scope_id IS NOT DISTINCT FROM
              lease.governed_scope_id
          AND issuing_decision.classification_key IS NOT DISTINCT FROM
              lease.classification_key
          AND issuing_decision.authorization_policy_version_id =
              lease.authorization_policy_version_id
          AND issuing_decision.requested_use_mode = lease.use_mode
          AND issuing_decision.requested_usage_limit IS NOT DISTINCT FROM
              lease.usage_limit
          AND issuing_decision.lease_audience = lease.lease_audience
          AND policy_version.decision_class = issuing_decision.decision_class
          AND policy_version.status = 'ACTIVE'
          AND policy_version.valid_from <= pg_catalog.statement_timestamp()
          AND (
              policy_version.valid_until IS NULL
              OR pg_catalog.statement_timestamp() < policy_version.valid_until
          )
          AND policy_version.lease_use_mode = lease.use_mode
          AND policy_version.lease_usage_limit IS NOT DISTINCT FROM
              lease.usage_limit
          AND policy_version.lease_audience = lease.lease_audience
          AND (
              policy_version.service_id IS NULL
              OR policy_version.service_id = lease.service_id
          )
          AND (
              policy_version.purpose_definition_id IS NULL
              OR policy_version.purpose_definition_id =
                 lease.purpose_definition_id
          )
          AND (
              policy_version.operation_definition_id IS NULL
              OR policy_version.operation_definition_id =
                 lease.operation_definition_id
          )
          AND (
              policy_version.requester_organization_id IS NULL
              OR policy_version.requester_organization_id IS NOT DISTINCT FROM
                 lease.requester_organization_id
          )
          AND (
              policy_version.applies_to_all_governed_scopes
              OR policy_version.governed_scope_id IS NOT DISTINCT FROM
                 lease.governed_scope_id
          )
          AND (
              policy_version.applies_to_all_targets
              OR (
                  policy_version.protected_target_type IS NOT DISTINCT FROM
                      lease.protected_target_type
                  AND policy_version.protected_target_reference IS NOT DISTINCT FROM
                      lease.protected_target_reference
              )
          )
          AND (
              policy_version.classification_key IS NULL
              OR policy_version.classification_key IS NOT DISTINCT FROM
                 lease.classification_key
          )
          AND NOT EXISTS (
              SELECT 1
              FROM decision.evaluation_records AS evaluation
              JOIN decision.supporting_records AS supporting
                ON supporting.evaluation_id = evaluation.evaluation_id
              WHERE evaluation.decision_id = issuing_decision.decision_id
                AND supporting.required_for_result
                AND (
                    (
                        supporting.effective_from IS NOT NULL
                        AND supporting.effective_from >
                            pg_catalog.statement_timestamp()
                    )
                    OR (
                        supporting.effective_until IS NOT NULL
                        AND pg_catalog.statement_timestamp() >=
                            supporting.effective_until
                    )
                )
          )
          AND NOT EXISTS (
              SELECT 1
              FROM access_control.lease_authority_grants AS lease_authority
              JOIN access_control.authority_grants AS authority_grant
                ON authority_grant.authority_grant_id =
                   lease_authority.authority_grant_id
              WHERE lease_authority.authorization_lease_id =
                    lease.authorization_lease_id
                AND (
                    authority_grant.status <> 'ACTIVE'
                    OR authority_grant.valid_from >
                       pg_catalog.statement_timestamp()
                    OR (
                        authority_grant.valid_until IS NOT NULL
                        AND pg_catalog.statement_timestamp() >=
                            authority_grant.valid_until
                    )
                    OR (
                        authority_grant.service_id IS NOT NULL
                        AND authority_grant.service_id <> lease.service_id
                    )
                    OR (
                        authority_grant.purpose_definition_id IS NOT NULL
                        AND authority_grant.purpose_definition_id IS DISTINCT FROM
                            lease.purpose_definition_id
                    )
                    OR (
                        authority_grant.operation_definition_id IS NOT NULL
                        AND authority_grant.operation_definition_id <>
                            lease.operation_definition_id
                    )
                    OR (
                        authority_grant.organization_id IS NOT NULL
                        AND authority_grant.organization_id IS DISTINCT FROM
                            lease.requester_organization_id
                    )
                    OR authority_grant.scope_reference IS NOT NULL
                    OR NOT (
                        authority_grant.applies_to_all_governed_scopes
                        OR authority_grant.governed_scope_id IS NOT DISTINCT FROM
                           lease.governed_scope_id
                    )
                    OR NOT (
                        authority_grant.applies_to_all_targets
                        OR (
                            authority_grant.protected_target_type IS NOT DISTINCT FROM
                                lease.protected_target_type
                            AND authority_grant.protected_target_reference IS NOT DISTINCT FROM
                                lease.protected_target_reference
                        )
                    )
                )
          )
          AND session_record.status = 'ACTIVE'
          AND session_record.authenticated_at <=
              pg_catalog.statement_timestamp()
          AND pg_catalog.statement_timestamp() < session_record.expires_at
          AND (
              session_record.inactivity_timeout IS NULL
              OR pg_catalog.statement_timestamp() < COALESCE(
                  session_record.last_activity_at,
                  session_record.authenticated_at
              ) + session_record.inactivity_timeout
          )
          AND session_record.identity_id = lease.identity_id
          AND session_record.organization_id IS NOT DISTINCT FROM
              lease.requester_organization_id
          AND session_record.device_id IS NOT DISTINCT FROM lease.device_id
          AND session_record.service_id IS NOT DISTINCT FROM lease.service_id
          AND access_control.session_context_is_locally_usable(
              session_record.identity_id,
              session_record.device_id,
              session_record.trust_provider_id,
              session_record.service_id,
              session_record.organization_id,
              provider_record.environment_key,
              pg_catalog.statement_timestamp()
          )
          AND (
              lease.use_mode = 'REUSABLE'
              OR (
                  lease.use_mode = 'SINGLE_USE'
                  AND lease.successful_use_count = 0
              )
              OR (
                  lease.use_mode = 'LIMITED_USE'
                  AND lease.successful_use_count < lease.usage_limit
              )
          )
    );
$function$;

COMMENT ON FUNCTION access_control.authorization_lease_context_is_usable(
    uuid, text, uuid, uuid, uuid, uuid, uuid, uuid, uuid,
    text, text, uuid, text, uuid, text
) IS
    'Return true only when the lease secret, lifecycle, authoritative time, use state, audience, complete authorization context, issuing ALLOW decision, active session, and current locally owned trust state all remain usable.';

REVOKE ALL ON FUNCTION access_control.authorization_lease_context_is_usable(
    uuid, text, uuid, uuid, uuid, uuid, uuid, uuid, uuid,
    text, text, uuid, text, uuid, text
) FROM PUBLIC;

CREATE FUNCTION access_control.consume_authorization_lease(
    p_authorization_lease_id uuid,
    p_plaintext_secret text,
    p_request_id uuid,
    p_identity_id uuid,
    p_requester_organization_id uuid,
    p_session_id uuid,
    p_device_id uuid,
    p_service_id uuid,
    p_purpose_definition_id uuid,
    p_operation_definition_id uuid,
    p_protected_target_type text,
    p_protected_target_reference text,
    p_governed_scope_id uuid,
    p_classification_key text,
    p_authorization_policy_version_id uuid,
    p_lease_audience text,
    p_decision_reference uuid,
    p_correlation_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control, decision
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_use_number integer;
BEGIN
    IF p_request_id IS NULL
       OR p_decision_reference IS NULL
       OR p_correlation_id IS NULL
    THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Lease-use attribution is incomplete';
    END IF;

    UPDATE access_control.authorization_leases AS lease
    SET
        successful_use_count = lease.successful_use_count + 1,
        status = CASE
            WHEN lease.use_mode = 'SINGLE_USE' THEN 'CONSUMED'
            WHEN lease.use_mode = 'LIMITED_USE'
                 AND lease.successful_use_count + 1 = lease.usage_limit
            THEN 'CONSUMED'
            ELSE 'ACTIVE'
        END,
        consumed_at = CASE
            WHEN lease.use_mode = 'SINGLE_USE' THEN v_now
            WHEN lease.use_mode = 'LIMITED_USE'
                 AND lease.successful_use_count + 1 = lease.usage_limit
            THEN v_now
            ELSE NULL
        END
    WHERE lease.authorization_lease_id = p_authorization_lease_id
      AND lease.status = 'ACTIVE'
      AND lease.consumed_at IS NULL
      AND lease.revoked_at IS NULL
      AND lease.expired_at IS NULL
      AND lease.not_before <= v_now
      AND v_now < lease.expires_at
      AND (
          lease.use_mode = 'REUSABLE'
          OR (
              lease.use_mode = 'SINGLE_USE'
              AND lease.successful_use_count = 0
          )
          OR (
              lease.use_mode = 'LIMITED_USE'
              AND lease.successful_use_count < lease.usage_limit
          )
      )
      AND access_control.authorization_lease_context_is_usable(
          lease.authorization_lease_id,
          p_plaintext_secret,
          p_identity_id,
          p_requester_organization_id,
          p_session_id,
          p_device_id,
          p_service_id,
          p_purpose_definition_id,
          p_operation_definition_id,
          p_protected_target_type,
          p_protected_target_reference,
          p_governed_scope_id,
          p_classification_key,
          p_authorization_policy_version_id,
          p_lease_audience
      )
      AND EXISTS (
          SELECT 1
          FROM decision.decision_records AS use_decision
          WHERE use_decision.decision_id = p_decision_reference
            AND use_decision.request_id = p_request_id
            AND use_decision.correlation_id = p_correlation_id
            AND use_decision.decision_class = 'PROTECTED_OPERATION'
            AND use_decision.record_status = 'FINALIZED'
            AND use_decision.final_result = 'ALLOW'
            AND use_decision.authorization_lease_id =
                lease.authorization_lease_id
            AND use_decision.requester_identity_id = lease.identity_id
            AND use_decision.requester_organization_id IS NOT DISTINCT FROM
                lease.requester_organization_id
            AND use_decision.session_id = lease.session_id
            AND use_decision.device_id IS NOT DISTINCT FROM lease.device_id
            AND use_decision.service_id IS NOT DISTINCT FROM lease.service_id
            AND use_decision.purpose_definition_id IS NOT DISTINCT FROM
                lease.purpose_definition_id
            AND use_decision.operation_definition_id =
                lease.operation_definition_id
            AND use_decision.protected_target_type IS NOT DISTINCT FROM
                lease.protected_target_type
            AND use_decision.protected_target_reference IS NOT DISTINCT FROM
                lease.protected_target_reference
            AND use_decision.governed_scope_id IS NOT DISTINCT FROM
                lease.governed_scope_id
            AND use_decision.classification_key IS NOT DISTINCT FROM
                lease.classification_key
      )
    RETURNING lease.successful_use_count INTO v_use_number;

    IF v_use_number IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_authorization_specification',
            MESSAGE = 'Authorization Lease is unavailable';
    END IF;

    INSERT INTO access_control.authorization_lease_use_events (
        authorization_lease_id,
        request_id,
        use_number,
        used_at,
        decision_reference,
        correlation_id
    ) VALUES (
        p_authorization_lease_id,
        p_request_id,
        v_use_number,
        v_now,
        p_decision_reference,
        p_correlation_id
    );

    RETURN v_use_number;
END;
$function$;

COMMENT ON FUNCTION access_control.consume_authorization_lease(
    uuid, text, uuid, uuid, uuid, uuid, uuid, uuid, uuid, uuid,
    text, text, uuid, text, uuid, text, uuid, uuid
) IS
    'Atomically consume one exact-context Authorization Lease use, revalidate current session and local trust state, require a finalized matching protected-operation Decision Record, enforce use limits, and append one attributable use event in the same transaction.';

REVOKE ALL ON FUNCTION access_control.consume_authorization_lease(
    uuid, text, uuid, uuid, uuid, uuid, uuid, uuid, uuid, uuid,
    text, text, uuid, text, uuid, text, uuid, uuid
) FROM PUBLIC;

CREATE FUNCTION access_control.expire_authorization_lease(
    p_authorization_lease_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
BEGIN
    UPDATE access_control.authorization_leases
    SET
        status = 'EXPIRED',
        expired_at = v_now
    WHERE authorization_lease_id = p_authorization_lease_id
      AND status = 'ACTIVE'
      AND v_now >= expires_at;

    RETURN FOUND;
END;
$function$;

COMMENT ON FUNCTION access_control.expire_authorization_lease(uuid) IS
    'Materialize the EXPIRED terminal state for one ACTIVE Authorization Lease only after its authoritative expiration deadline has been reached.';

REVOKE ALL ON FUNCTION access_control.expire_authorization_lease(uuid)
    FROM PUBLIC;

CREATE OR REPLACE FUNCTION access_control.revoke_lease(
    p_authorization_lease_id uuid,
    p_reason text
)
RETURNS boolean
LANGUAGE plpgsql
SET search_path = pg_catalog, access_control
AS $function$
DECLARE
    v_now timestamptz := pg_catalog.statement_timestamp();
    v_reason text;
BEGIN
    v_reason := pg_catalog.btrim(p_reason);

    IF p_reason IS NULL
       OR v_reason = ''
       OR v_reason !~ '^[A-Z][A-Z0-9_]*$'
    THEN
        RAISE EXCEPTION USING
            ERRCODE = 'invalid_parameter_value',
            MESSAGE = 'Authorization Lease revocation reason must be a stable reason code';
    END IF;

    UPDATE access_control.authorization_leases
    SET
        status = 'REVOKED',
        revoked_at = v_now,
        revocation_reason = v_reason
    WHERE authorization_lease_id = p_authorization_lease_id
      AND status = 'ACTIVE';

    RETURN FOUND;
END;
$function$;

COMMENT ON FUNCTION access_control.revoke_lease(uuid, text) IS
    'Atomically transition one ACTIVE Authorization Lease to terminal REVOKED using one PostgreSQL statement time and an attributable stable reason code. Consumed, expired, and already revoked leases remain terminal.';

REVOKE ALL ON FUNCTION access_control.revoke_lease(uuid, text)
    FROM PUBLIC;

SELECT foundation_meta.register_migration(
    p_migration_id => '081_postgresql_authorization_decision_and_lease_issuance',
    p_migration_name => 'PostgreSQL authorization decision and lease issuance structure',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Added typed policy applicability, exact policy-stage mapping, lease-request Decision Record fields, one issuing-decision/one issued-lease cardinality, core decision-to-lease context binding, lease chronology and state shape, attributable authority and use evidence, deterministic policy resolution, controlled policy binding, finalization-once Decision Record closure, controlled lease issuance, exact-context usability, atomic use, expiration, and revocation.'
);

COMMIT;
