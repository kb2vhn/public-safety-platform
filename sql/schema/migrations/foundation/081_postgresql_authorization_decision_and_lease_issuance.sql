-- ============================================================================
-- Migration: 081_postgresql_authorization_decision_and_lease_issuance.sql
-- Title: PostgreSQL authorization decision and lease issuance structure
-- Layer: Platform Foundation
-- Status: PHASE 3 STEP 3 IMPLEMENTATION CANDIDATE
-- Target: PostgreSQL 18
-- Compatibility policy: prefer mature features supported before PostgreSQL 18.
-- ============================================================================
--
-- Purpose:
-- Establish the typed relational boundary required before controlled
-- authorization policy selection, Decision Record finalization, and
-- Authorization Lease issuance are implemented.
--
-- Step 3 adds deterministic policy resolution, controlled policy binding,
-- required-stage closure, and finalization-once Decision Record behavior.
-- Authorization Lease issuance remains Phase 3 Step 4.
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

SELECT foundation_meta.register_migration(
    p_migration_id => '081_postgresql_authorization_decision_and_lease_issuance',
    p_migration_name => 'PostgreSQL authorization decision and lease issuance structure',
    p_migration_layer => 'FOUNDATION',
    p_migration_checksum => NULL,
    p_notes => 'Added typed policy applicability, exact policy-stage mapping, lease-request Decision Record fields, one-decision/one-lease cardinality, core decision-to-lease context binding, lease chronology and state shape, attributable authority and use evidence, deterministic policy resolution, controlled policy binding, and finalization-once Decision Record closure.'
);

COMMIT;
