-- ============================================================================
-- Migration: 930_investigator_audit_and_validation_review_surfaces.sql
-- Title: Investigator, Audit, and Validation Review Surfaces
-- Layer: Deployment and Bootstrap
-- Status: PHASE 5 STEP 5 CANDIDATE
-- Target: PostgreSQL 18
-- ============================================================================
--
-- Purpose:
-- - Implement separate read-only investigator, audit-reader, and
--   validation-reader database boundaries.
-- - Expose only approved views; do not grant direct protected-base-table
--   access.
-- - Keep investigator disclosure deliberately reduced, provide audit lineage
--   without secret material or raw context payloads, and expose posture data
--   to validation readers without protected business-row access.
--
-- Security boundary:
-- - Review roles remain NOLOGIN capability roles.
-- - No review role owns objects, creates schemas, creates temporary objects,
--   executes protected routines, or receives table-write or sequence access.
-- - No service login inherits a review role.
-- - The review allowlist is exact and recorded in deployment metadata.
-- - Credential provisioning remains outside repository SQL.
-- - Break-glass activation remains deferred to Phase 5 Step 6.
--
-- Required psql variables supplied by apply_deployment.sh:
-- - deployment_migration_checksum
-- - deployment_migration_relative_path
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';

SELECT pg_advisory_xact_lock(
    hashtext(current_database()),
    hashtext('iron-signal-platform-deployment-migrations')
);

-- ============================================================================
-- Dependency and execution-authority validation
-- ============================================================================

DO $deployment_dependency_check$
DECLARE
    v_foundation_migration_count bigint;
    v_missing_roles text;
BEGIN
    IF current_setting('server_version_num')::integer < 180000 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'feature_not_supported',
            MESSAGE = 'Iron Signal Platform deployment migrations require PostgreSQL 18 or newer',
            DETAIL = format(
                'Detected server_version_num=%s.',
                current_setting('server_version_num')
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = current_user
          AND role_record.rolsuper
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'insufficient_privilege',
            MESSAGE = 'Phase 5 Step 5 review-surface bootstrap requires a PostgreSQL superuser',
            DETAIL = format('Connected role=%I.', current_user),
            HINT = 'Use the controlled deployment bootstrap identity.';
    END IF;

    SELECT count(*)
    INTO v_foundation_migration_count
    FROM foundation_meta.applied_migrations;

    IF v_foundation_migration_count <> 34 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'The accepted 34-migration Platform Foundation is required before review grants',
            DETAIL = format(
                'Registered Foundation migrations=%s.',
                v_foundation_migration_count
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM deployment_meta.applied_deployment_migrations
        WHERE migration_id =
            '920_least_privileged_runtime_grants_and_controlled_service_apis'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'Required deployment migration 920 is not registered';
    END IF;

    SELECT string_agg(required_role.role_name, ', ' ORDER BY required_role.role_name)
    INTO v_missing_roles
    FROM (
        VALUES
            ('issp_foundation_owner'::name),
            ('issp_database_owner'::name),
            ('issp_read_only_investigator'::name),
            ('issp_audit_reader'::name),
            ('issp_validation_reader'::name)
    ) AS required_role(role_name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_roles AS role_record
        WHERE role_record.rolname = required_role.role_name
    );

    IF v_missing_roles IS NOT NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'undefined_object',
            MESSAGE = 'One or more canonical Phase 5 review roles are missing',
            DETAIL = v_missing_roles;
    END IF;
END;
$deployment_dependency_check$;

-- ============================================================================
-- Dedicated review schema
-- ============================================================================

CREATE SCHEMA security_review AUTHORIZATION issp_foundation_owner;

COMMENT ON SCHEMA security_review IS
    'Approved reduced-disclosure investigator and append-oriented audit review views. The schema contains no writable business tables.';

REVOKE ALL ON SCHEMA security_review FROM PUBLIC;

INSERT INTO foundation_meta.schema_registry (
    schema_name,
    capability_key,
    architectural_layer,
    purpose,
    created_by_migration_id
)
VALUES (
    'security_review',
    'security_review_surfaces',
    'DEPLOYMENT',
    'Approved investigator and audit review views with no direct protected-base-table grants.',
    '930_investigator_audit_and_validation_review_surfaces'
);

ALTER DEFAULT PRIVILEGES FOR ROLE issp_foundation_owner
    IN SCHEMA security_review
    REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES FOR ROLE issp_foundation_owner
    IN SCHEMA security_review
    REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES FOR ROLE issp_foundation_owner
    IN SCHEMA security_review
    REVOKE ALL PRIVILEGES ON ROUTINES FROM PUBLIC;

ALTER DEFAULT PRIVILEGES FOR ROLE issp_foundation_owner
    IN SCHEMA security_review
    REVOKE ALL PRIVILEGES ON TYPES FROM PUBLIC;

-- ============================================================================
-- Reduced-disclosure investigator views
-- ============================================================================

CREATE VIEW security_review.investigator_decision_summary
WITH (security_barrier = true)
AS
SELECT
    decision_record.decision_id,
    decision_record.parent_decision_id,
    decision_record.request_id,
    decision_record.correlation_id,
    decision_record.decision_class,
    decision_record.service_id,
    decision_record.operation_definition_id,
    decision_record.operation_key,
    decision_record.protected_target_type,
    decision_record.governed_scope_id,
    decision_record.classification_key,
    decision_record.record_status,
    decision_record.final_result,
    decision_record.primary_reason_code,
    decision_record.requested_at,
    decision_record.evaluated_at,
    decision_record.finalized_at,
    decision_record.evaluator_name,
    decision_record.evaluator_version,
    decision_record.database_schema_version
FROM decision.decision_records AS decision_record
WHERE decision_record.record_status = 'FINALIZED';

COMMENT ON VIEW security_review.investigator_decision_summary IS
    'Reduced-disclosure finalized Decision Record summary. Identity, device, session, raw target reference, context snapshot, and record-hash material are intentionally excluded.';

CREATE VIEW security_review.investigator_approval_summary
WITH (security_barrier = true)
AS
SELECT
    request_record.approval_request_id,
    request_record.approval_policy_id,
    request_record.approval_chain_id,
    request_record.correlation_id,
    request_record.service_id,
    request_record.purpose_definition_id,
    request_record.operation_definition_id,
    request_record.purpose_key,
    request_record.operation_key,
    request_record.protected_target_type,
    request_record.governed_scope_id,
    request_record.classification_key,
    request_record.status,
    request_record.requested_at,
    request_record.expires_at,
    request_record.finalized_at,
    request_record.final_reason_code
FROM approval.approval_requests AS request_record;

COMMENT ON VIEW security_review.investigator_approval_summary IS
    'Reduced-disclosure Approval Request summary. Requester, affected identity, session, organization, and raw target reference are intentionally excluded.';

-- ============================================================================
-- Audit lineage views
-- ============================================================================

CREATE VIEW security_review.audit_decision_records
WITH (security_barrier = true)
AS
SELECT
    decision_record.decision_id,
    decision_record.parent_decision_id,
    decision_record.request_id,
    decision_record.correlation_id,
    decision_record.decision_class,
    decision_record.requester_identity_id,
    decision_record.requester_organization_id,
    decision_record.device_id,
    decision_record.session_id,
    decision_record.authentication_assertion_id,
    decision_record.authorization_lease_id,
    decision_record.approval_request_id,
    decision_record.authorization_policy_version_id,
    decision_record.service_id,
    decision_record.purpose_definition_id,
    decision_record.operation_definition_id,
    decision_record.operation_key,
    decision_record.protected_target_type,
    decision_record.protected_target_reference,
    decision_record.governed_scope_id,
    decision_record.classification_key,
    decision_record.record_status,
    decision_record.final_result,
    decision_record.primary_reason_code,
    decision_record.requested_at,
    decision_record.evaluated_at,
    decision_record.finalized_at,
    decision_record.evaluator_name,
    decision_record.evaluator_version,
    decision_record.database_schema_version,
    pg_catalog.encode(decision_record.record_hash, 'hex') AS record_hash_hex,
    pg_catalog.encode(
        decision_record.previous_record_hash,
        'hex'
    ) AS previous_record_hash_hex
FROM decision.decision_records AS decision_record;

COMMENT ON VIEW security_review.audit_decision_records IS
    'Audit review of Decision Record identity, context linkage, result, chronology, and hash lineage. Raw context_snapshot is excluded.';

CREATE VIEW security_review.audit_decision_evaluations
WITH (security_barrier = true)
AS
SELECT
    evaluation_record.evaluation_id,
    evaluation_record.decision_id,
    evaluation_record.parent_evaluation_id,
    evaluation_record.evaluation_order,
    evaluation_record.evaluation_key,
    evaluation_record.required,
    evaluation_record.result,
    evaluation_record.reason_code,
    evaluation_record.explanation,
    evaluation_record.evaluated_at,
    evaluation_record.duration_microseconds
FROM decision.evaluation_records AS evaluation_record;

COMMENT ON VIEW security_review.audit_decision_evaluations IS
    'Audit review of ordered Decision Record evaluation outcomes. Raw supporting_context is excluded.';

CREATE VIEW security_review.audit_approval_requests
WITH (security_barrier = true)
AS
SELECT
    request_record.approval_request_id,
    request_record.approval_policy_id,
    request_record.approval_chain_id,
    request_record.correlation_id,
    request_record.requester_identity_id,
    request_record.requester_organization_id,
    request_record.requester_session_id,
    request_record.directly_affected_identity_id,
    request_record.service_id,
    request_record.purpose_definition_id,
    request_record.operation_definition_id,
    request_record.purpose_key,
    request_record.operation_key,
    request_record.protected_target_type,
    request_record.protected_target_reference,
    request_record.governed_scope_id,
    request_record.classification_key,
    request_record.status,
    request_record.requested_at,
    request_record.expires_at,
    request_record.finalized_at,
    request_record.finalized_by_identity_id,
    request_record.final_reason_code
FROM approval.approval_requests AS request_record;

COMMENT ON VIEW security_review.audit_approval_requests IS
    'Audit review of Approval Request actors, governed context, status, and finalization chronology.';

CREATE VIEW security_review.audit_approval_actions
WITH (security_barrier = true)
AS
SELECT
    action_record.approval_action_id,
    action_record.approval_request_id,
    action_record.approval_policy_stage_id,
    action_record.acting_identity_id,
    action_record.effective_actor_identity_id,
    action_record.acting_organization_id,
    action_record.acting_session_id,
    action_record.authority_grant_id,
    action_record.prior_approval_action_id,
    action_record.action_type,
    action_record.action_reason,
    action_record.action_reason_code,
    action_record.action_at
FROM approval.approval_actions AS action_record;

COMMENT ON VIEW security_review.audit_approval_actions IS
    'Audit review of append-oriented Approval Action actor, authority, lineage, action, reason, and chronology.';

CREATE VIEW security_review.audit_approval_stage_evaluations
WITH (security_barrier = true)
AS
SELECT
    evaluation_record.approval_stage_evaluation_id,
    evaluation_record.approval_request_id,
    evaluation_record.approval_policy_stage_id,
    evaluation_record.evaluated_at,
    evaluation_record.result,
    evaluation_record.reason_code,
    evaluation_record.required_approvals,
    evaluation_record.counted_approvals,
    evaluation_record.distinct_effective_actors,
    evaluation_record.distinct_organizations,
    evaluation_record.blocking_deny_present,
    evaluation_record.finalized_evaluation
FROM approval.approval_stage_evaluations AS evaluation_record;

COMMENT ON VIEW security_review.audit_approval_stage_evaluations IS
    'Audit review of persisted Approval Stage satisfaction, denial, actor, organization, and finalization results.';

CREATE VIEW security_review.audit_session_events
WITH (security_barrier = true)
AS
SELECT
    event_record.session_event_id,
    event_record.session_id,
    event_record.event_type,
    event_record.event_at,
    event_record.acting_identity_id,
    event_record.actor_reference,
    event_record.reason_code
FROM access_control.session_events AS event_record;

COMMENT ON VIEW security_review.audit_session_events IS
    'Audit review of append-oriented session lifecycle events. Free-form details JSON is excluded.';

CREATE VIEW security_review.audit_authorization_lease_events
WITH (security_barrier = true)
AS
SELECT
    use_event.authorization_lease_use_event_id,
    use_event.authorization_lease_id,
    use_event.request_id,
    use_event.use_number,
    use_event.used_at,
    use_event.decision_reference,
    use_event.correlation_id,
    lease_record.session_id,
    lease_record.identity_id,
    lease_record.requester_organization_id,
    lease_record.device_id,
    lease_record.service_id,
    lease_record.purpose_definition_id,
    lease_record.operation_definition_id,
    lease_record.protected_target_type,
    lease_record.protected_target_reference,
    lease_record.governed_scope_id,
    lease_record.classification_key,
    lease_record.authorization_policy_version_id,
    lease_record.approval_request_id,
    lease_record.issuing_decision_id,
    lease_record.use_mode,
    lease_record.usage_limit,
    lease_record.successful_use_count,
    lease_record.issued_at,
    lease_record.expires_at,
    lease_record.consumed_at,
    lease_record.status,
    lease_record.revoked_at,
    lease_record.revocation_reason
FROM access_control.authorization_lease_use_events AS use_event
JOIN access_control.authorization_leases AS lease_record
  ON lease_record.authorization_lease_id = use_event.authorization_lease_id;

COMMENT ON VIEW security_review.audit_authorization_lease_events IS
    'Audit review of Authorization Lease use and lifecycle context. lease_secret_hash is intentionally excluded.';

CREATE VIEW security_review.audit_lifecycle_events
WITH (security_barrier = true)
AS
SELECT
    lifecycle_event.lifecycle_event_id,
    lifecycle_event.object_type,
    lifecycle_event.stable_object_id,
    lifecycle_event.event_type,
    lifecycle_event.valid_at,
    lifecycle_event.recorded_at,
    lifecycle_event.previous_state,
    lifecycle_event.new_state,
    lifecycle_event.reason,
    lifecycle_event.decision_id
FROM governance.lifecycle_events AS lifecycle_event;

COMMENT ON VIEW security_review.audit_lifecycle_events IS
    'Audit review of append-oriented governed-object lifecycle transitions and Decision Record linkage.';

DO $normalize_review_view_owners$
DECLARE
    v_view_name text;
BEGIN
    FOREACH v_view_name IN ARRAY ARRAY[
        'security_review.investigator_decision_summary',
        'security_review.investigator_approval_summary',
        'security_review.audit_decision_records',
        'security_review.audit_decision_evaluations',
        'security_review.audit_approval_requests',
        'security_review.audit_approval_actions',
        'security_review.audit_approval_stage_evaluations',
        'security_review.audit_session_events',
        'security_review.audit_authorization_lease_events',
        'security_review.audit_lifecycle_events'
    ]
    LOOP
        EXECUTE format('ALTER VIEW %s OWNER TO issp_foundation_owner', v_view_name);
        EXECUTE format('REVOKE ALL ON TABLE %s FROM PUBLIC', v_view_name);
    END LOOP;
END;
$normalize_review_view_owners$;

-- ============================================================================
-- Deployment-validation views
-- ============================================================================

CREATE VIEW deployment_meta.deployment_migration_status
WITH (security_barrier = true)
AS
SELECT
    migration_record.migration_id,
    migration_record.migration_name,
    migration_record.migration_layer,
    migration_record.migration_checksum,
    migration_record.relative_path,
    migration_record.applied_at,
    migration_record.applied_by,
    migration_record.database_name,
    migration_record.server_version_num,
    migration_record.application_name,
    migration_record.transaction_id,
    migration_record.notes
FROM deployment_meta.applied_deployment_migrations AS migration_record;

COMMENT ON VIEW deployment_meta.deployment_migration_status IS
    'Validation-reader surface for exact deployment migration registration and checksums.';

CREATE VIEW deployment_meta.canonical_role_posture
WITH (security_barrier = true)
AS
SELECT
    expected_role.role_name,
    expected_role.role_class_key,
    expected_role.login_allowed AS expected_login_allowed,
    expected_role.ownership_role,
    expected_role.capability_role,
    expected_role.break_glass_only,
    expected_role.expected_connection_limit,
    expected_role.credential_state,
    actual_role.rolcanlogin AS actual_login_allowed,
    actual_role.rolinherit AS actual_inherit,
    actual_role.rolconnlimit AS actual_connection_limit,
    actual_role.rolsuper,
    actual_role.rolcreatedb,
    actual_role.rolcreaterole,
    actual_role.rolreplication,
    actual_role.rolbypassrls,
    CASE
        WHEN actual_role.rolname IS NULL THEN 'MISSING'
        WHEN actual_role.rolcanlogin IS DISTINCT FROM expected_role.login_allowed
          OR actual_role.rolconnlimit IS DISTINCT FROM
                expected_role.expected_connection_limit
          OR actual_role.rolsuper
          OR actual_role.rolcreatedb
          OR actual_role.rolcreaterole
          OR actual_role.rolreplication
          OR actual_role.rolbypassrls
        THEN 'FAIL'
        ELSE 'PASS'
    END AS posture_status
FROM deployment_meta.database_roles AS expected_role
LEFT JOIN pg_roles AS actual_role
  ON actual_role.rolname = expected_role.role_name;

COMMENT ON VIEW deployment_meta.canonical_role_posture IS
    'Validation-reader surface comparing canonical role metadata with non-secret pg_roles attributes.';

CREATE VIEW deployment_meta.canonical_membership_posture
WITH (security_barrier = true)
AS
SELECT
    expected_membership.granted_role_name,
    expected_membership.member_role_name,
    expected_membership.inherit_option AS expected_inherit_option,
    expected_membership.set_option AS expected_set_option,
    expected_membership.admin_option AS expected_admin_option,
    actual_membership.inherit_option AS actual_inherit_option,
    actual_membership.set_option AS actual_set_option,
    actual_membership.admin_option AS actual_admin_option,
    CASE
        WHEN actual_membership.roleid IS NULL THEN 'MISSING'
        WHEN actual_membership.inherit_option IS DISTINCT FROM
                expected_membership.inherit_option
          OR actual_membership.set_option IS DISTINCT FROM
                expected_membership.set_option
          OR actual_membership.admin_option IS DISTINCT FROM
                expected_membership.admin_option
        THEN 'FAIL'
        ELSE 'PASS'
    END AS posture_status
FROM deployment_meta.database_role_memberships AS expected_membership
LEFT JOIN pg_roles AS granted_role
  ON granted_role.rolname = expected_membership.granted_role_name
LEFT JOIN pg_roles AS member_role
  ON member_role.rolname = expected_membership.member_role_name
LEFT JOIN pg_auth_members AS actual_membership
  ON actual_membership.roleid = granted_role.oid
 AND actual_membership.member = member_role.oid;

COMMENT ON VIEW deployment_meta.canonical_membership_posture IS
    'Validation-reader surface comparing approved canonical memberships with pg_auth_members options.';

DO $normalize_deployment_validation_view_owners$
DECLARE
    v_view_name text;
BEGIN
    FOREACH v_view_name IN ARRAY ARRAY[
        'deployment_meta.deployment_migration_status',
        'deployment_meta.canonical_role_posture',
        'deployment_meta.canonical_membership_posture'
    ]
    LOOP
        EXECUTE format('ALTER VIEW %s OWNER TO issp_database_owner', v_view_name);
        EXECUTE format('REVOKE ALL ON TABLE %s FROM PUBLIC', v_view_name);
    END LOOP;
END;
$normalize_deployment_validation_view_owners$;

-- ============================================================================
-- Exact review privilege contract
-- ============================================================================

CREATE TABLE deployment_meta.review_privilege_contract (
    grantee_role_name name NOT NULL,
    object_kind text NOT NULL,
    object_identity text NOT NULL,
    privilege_type text NOT NULL,
    disclosure_class text NOT NULL,
    notes text NOT NULL,
    introduced_by_migration_id text NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT review_privilege_contract_pk PRIMARY KEY (
        grantee_role_name,
        object_kind,
        object_identity,
        privilege_type
    ),
    CONSTRAINT review_privilege_contract_role_fk FOREIGN KEY (
        grantee_role_name
    ) REFERENCES deployment_meta.database_roles(role_name),
    CONSTRAINT review_privilege_contract_kind_ck CHECK (
        object_kind IN ('DATABASE', 'SCHEMA', 'VIEW')
    ),
    CONSTRAINT review_privilege_contract_privilege_ck CHECK (
        (object_kind = 'DATABASE' AND privilege_type = 'CONNECT')
        OR (object_kind = 'SCHEMA' AND privilege_type = 'USAGE')
        OR (object_kind = 'VIEW' AND privilege_type = 'SELECT')
    ),
    CONSTRAINT review_privilege_contract_disclosure_ck CHECK (
        disclosure_class IN (
            'REDUCED_INVESTIGATIVE',
            'AUDIT_LINEAGE',
            'VALIDATION_POSTURE'
        )
    ),
    CONSTRAINT review_privilege_contract_notes_ck CHECK (btrim(notes) <> '')
);

COMMENT ON TABLE deployment_meta.review_privilege_contract IS
    'Exact Phase 5 Step 5 allowlist for investigator, audit-reader, and validation-reader database, schema, and view privileges. Absence means access is not approved.';

ALTER TABLE deployment_meta.review_privilege_contract
    OWNER TO issp_database_owner;

INSERT INTO deployment_meta.review_privilege_contract (
    grantee_role_name,
    object_kind,
    object_identity,
    privilege_type,
    disclosure_class,
    notes,
    introduced_by_migration_id
)
VALUES
    -- Investigator: 4 rows.
    (
        'issp_read_only_investigator',
        'DATABASE',
        current_database(),
        'CONNECT',
        'REDUCED_INVESTIGATIVE',
        'Connection capability for a separately governed investigator login.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_read_only_investigator',
        'SCHEMA',
        'security_review',
        'USAGE',
        'REDUCED_INVESTIGATIVE',
        'Namespace access only for reduced-disclosure investigator views.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_read_only_investigator',
        'VIEW',
        'security_review.investigator_decision_summary',
        'SELECT',
        'REDUCED_INVESTIGATIVE',
        'Finalized Decision Record summary without direct identifiers or raw context.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_read_only_investigator',
        'VIEW',
        'security_review.investigator_approval_summary',
        'SELECT',
        'REDUCED_INVESTIGATIVE',
        'Approval Request summary without direct actor identifiers or raw target reference.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),

    -- Audit reader: 10 rows.
    (
        'issp_audit_reader',
        'DATABASE',
        current_database(),
        'CONNECT',
        'AUDIT_LINEAGE',
        'Connection capability for a separately governed audit login.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_audit_reader',
        'SCHEMA',
        'security_review',
        'USAGE',
        'AUDIT_LINEAGE',
        'Namespace access only for approved audit-lineage views.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_audit_reader',
        'VIEW',
        'security_review.audit_decision_records',
        'SELECT',
        'AUDIT_LINEAGE',
        'Decision Record context, final result, chronology, and hash lineage.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_audit_reader',
        'VIEW',
        'security_review.audit_decision_evaluations',
        'SELECT',
        'AUDIT_LINEAGE',
        'Ordered Decision Record evaluation outcomes without raw context JSON.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_audit_reader',
        'VIEW',
        'security_review.audit_approval_requests',
        'SELECT',
        'AUDIT_LINEAGE',
        'Approval Request context and finalization lineage.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_audit_reader',
        'VIEW',
        'security_review.audit_approval_actions',
        'SELECT',
        'AUDIT_LINEAGE',
        'Append-oriented Approval Action actor, authority, and prior-action lineage.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_audit_reader',
        'VIEW',
        'security_review.audit_approval_stage_evaluations',
        'SELECT',
        'AUDIT_LINEAGE',
        'Persisted stage evaluation counts, result, denial, and finalization state.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_audit_reader',
        'VIEW',
        'security_review.audit_session_events',
        'SELECT',
        'AUDIT_LINEAGE',
        'Append-oriented session lifecycle transitions without details JSON.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_audit_reader',
        'VIEW',
        'security_review.audit_authorization_lease_events',
        'SELECT',
        'AUDIT_LINEAGE',
        'Authorization Lease use and lifecycle context without secret hashes.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_audit_reader',
        'VIEW',
        'security_review.audit_lifecycle_events',
        'SELECT',
        'AUDIT_LINEAGE',
        'Governed-object lifecycle transitions and Decision Record linkage.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),

    -- Validation reader: database and schemas.
    (
        'issp_validation_reader',
        'DATABASE',
        current_database(),
        'CONNECT',
        'VALIDATION_POSTURE',
        'Connection capability for a separately governed validation login.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader',
        'SCHEMA',
        'security_validation',
        'USAGE',
        'VALIDATION_POSTURE',
        'Namespace access to accepted Foundation security-validation views.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader',
        'SCHEMA',
        'deployment_meta',
        'USAGE',
        'VALIDATION_POSTURE',
        'Namespace access to approved deployment-posture views only.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),

    -- Validation reader: 19 accepted Foundation validation views.
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.foundation_schemas', 'SELECT',
        'VALIDATION_POSTURE', 'Registered Foundation schema inventory.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.migration_summary', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation migration registration summary.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.migration_integrity_status', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation migration checksum review state.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.extension_inventory', 'SELECT',
        'VALIDATION_POSTURE', 'Approved extension inventory and ownership posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.public_schema_privileges', 'SELECT',
        'VALIDATION_POSTURE', 'PUBLIC schema privilege posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.foundation_schema_ownership', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation schema ownership posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.foundation_relation_ownership', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation relation ownership posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.foundation_function_ownership', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation function ownership posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.public_table_privileges', 'SELECT',
        'VALIDATION_POSTURE', 'PUBLIC table and view privilege posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.public_sequence_privileges', 'SELECT',
        'VALIDATION_POSTURE', 'PUBLIC sequence privilege posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.public_routine_privileges', 'SELECT',
        'VALIDATION_POSTURE', 'PUBLIC routine privilege posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.function_security_posture', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation function security configuration posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.security_definer_functions', 'SELECT',
        'VALIDATION_POSTURE', 'SECURITY DEFINER inventory and search-path posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.tables_without_primary_keys', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation regular-table primary-key posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.row_security_posture', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation table RLS and policy posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.expected_append_only_objects', 'SELECT',
        'VALIDATION_POSTURE', 'Expected append-oriented object inventory.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.append_only_posture', 'SELECT',
        'VALIDATION_POSTURE', 'Append-oriented grant and guard review posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.foundation_table_counts', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation table counts by schema.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'security_validation.foundation_review_summary', 'SELECT',
        'VALIDATION_POSTURE', 'Foundation review summary; repository parity remains external.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),

    -- Validation reader: 4 deployment posture views.
    (
        'issp_validation_reader', 'VIEW',
        'deployment_meta.deployment_migration_status', 'SELECT',
        'VALIDATION_POSTURE', 'Exact deployment migration checksums and application metadata.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'deployment_meta.canonical_role_posture', 'SELECT',
        'VALIDATION_POSTURE', 'Canonical role attributes without credential material.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'deployment_meta.canonical_membership_posture', 'SELECT',
        'VALIDATION_POSTURE', 'Canonical membership option posture.',
        '930_investigator_audit_and_validation_review_surfaces'
    ),
    (
        'issp_validation_reader', 'VIEW',
        'deployment_meta.review_privilege_contract_summary', 'SELECT',
        'VALIDATION_POSTURE', 'Combined non-secret runtime and review privilege allowlist summary.',
        '930_investigator_audit_and_validation_review_surfaces'
    );

DO $validate_review_contract_count$
DECLARE
    v_contract_count bigint;
BEGIN
    SELECT count(*)
    INTO v_contract_count
    FROM deployment_meta.review_privilege_contract;

    IF v_contract_count <> 40 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Review privilege contract row count is not 40',
            DETAIL = format('row_count=%s', v_contract_count);
    END IF;
END;
$validate_review_contract_count$;

CREATE VIEW deployment_meta.review_privilege_contract_summary
WITH (security_barrier = true)
AS
SELECT
    'RUNTIME'::text AS contract_class,
    runtime_contract.grantee_role_name,
    runtime_contract.object_kind,
    runtime_contract.object_identity,
    runtime_contract.privilege_type,
    CASE
        WHEN runtime_contract.security_definer_required
            THEN 'SECURITY_DEFINER_REQUIRED'
        ELSE 'NOT_REQUIRED'
    END AS disclosure_or_execution_class,
    runtime_contract.introduced_by_migration_id
FROM deployment_meta.runtime_privilege_contract AS runtime_contract

UNION ALL

SELECT
    'REVIEW'::text AS contract_class,
    review_contract.grantee_role_name,
    review_contract.object_kind,
    review_contract.object_identity,
    review_contract.privilege_type,
    review_contract.disclosure_class,
    review_contract.introduced_by_migration_id
FROM deployment_meta.review_privilege_contract AS review_contract;

COMMENT ON VIEW deployment_meta.review_privilege_contract_summary IS
    'Validation-reader summary of exact runtime and review privilege contracts without free-form notes.';

ALTER VIEW deployment_meta.review_privilege_contract_summary
    OWNER TO issp_database_owner;

REVOKE ALL ON TABLE deployment_meta.review_privilege_contract_summary
    FROM PUBLIC;

-- ============================================================================
-- Normalize deny-by-default review posture and apply the exact allowlist
-- ============================================================================

DO $revoke_unapproved_review_access$
DECLARE
    v_role_name name;
    v_schema_name name;
BEGIN
    FOREACH v_role_name IN ARRAY ARRAY[
        'issp_read_only_investigator'::name,
        'issp_audit_reader'::name,
        'issp_validation_reader'::name
    ]
    LOOP
        EXECUTE format(
            'REVOKE CONNECT, TEMPORARY ON DATABASE %I FROM %I',
            current_database(),
            v_role_name
        );

        FOREACH v_schema_name IN ARRAY ARRAY[
            'extensions'::name,
            'deployment_meta'::name,
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
            'security_validation'::name,
            'security_review'::name
        ]
        LOOP
            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON SCHEMA %I FROM %I',
                v_schema_name,
                v_role_name
            );
            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA %I FROM %I',
                v_schema_name,
                v_role_name
            );
            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA %I FROM %I',
                v_schema_name,
                v_role_name
            );
            EXECUTE format(
                'REVOKE ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA %I FROM %I',
                v_schema_name,
                v_role_name
            );
        END LOOP;
    END LOOP;
END;
$revoke_unapproved_review_access$;

DO $apply_review_privilege_contract$
DECLARE
    v_contract deployment_meta.review_privilege_contract%ROWTYPE;
    v_object_oid oid;
BEGIN
    FOR v_contract IN
        SELECT *
        FROM deployment_meta.review_privilege_contract
        ORDER BY
            grantee_role_name,
            object_kind,
            object_identity,
            privilege_type
    LOOP
        CASE v_contract.object_kind
            WHEN 'DATABASE' THEN
                EXECUTE format(
                    'GRANT CONNECT ON DATABASE %I TO %I',
                    v_contract.object_identity,
                    v_contract.grantee_role_name
                );

            WHEN 'SCHEMA' THEN
                IF pg_catalog.to_regnamespace(v_contract.object_identity) IS NULL THEN
                    RAISE EXCEPTION USING
                        ERRCODE = 'undefined_schema',
                        MESSAGE = 'Approved review schema does not exist',
                        DETAIL = v_contract.object_identity;
                END IF;

                EXECUTE format(
                    'GRANT USAGE ON SCHEMA %I TO %I',
                    v_contract.object_identity,
                    v_contract.grantee_role_name
                );

            WHEN 'VIEW' THEN
                v_object_oid := pg_catalog.to_regclass(v_contract.object_identity);

                IF v_object_oid IS NULL THEN
                    RAISE EXCEPTION USING
                        ERRCODE = 'undefined_table',
                        MESSAGE = 'Approved review view does not exist',
                        DETAIL = v_contract.object_identity;
                END IF;

                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_class AS relation_record
                    WHERE relation_record.oid = v_object_oid
                      AND relation_record.relkind IN ('v', 'm')
                ) THEN
                    RAISE EXCEPTION USING
                        ERRCODE = 'wrong_object_type',
                        MESSAGE = 'Review SELECT grants may target only views',
                        DETAIL = v_contract.object_identity;
                END IF;

                EXECUTE format(
                    'GRANT SELECT ON TABLE %s TO %I',
                    v_object_oid::regclass,
                    v_contract.grantee_role_name
                );

            ELSE
                RAISE EXCEPTION USING
                    ERRCODE = 'invalid_parameter_value',
                    MESSAGE = 'Unsupported review privilege object kind',
                    DETAIL = v_contract.object_kind;
        END CASE;
    END LOOP;
END;
$apply_review_privilege_contract$;

-- ============================================================================
-- Validate review role attributes, grants, and prohibited authority
-- ============================================================================

DO $validate_review_roles$
DECLARE
    v_violation_count bigint;
BEGIN
    SELECT count(*)
    INTO v_violation_count
    FROM pg_roles AS role_record
    WHERE role_record.rolname IN (
        'issp_read_only_investigator',
        'issp_audit_reader',
        'issp_validation_reader'
    )
      AND (
          role_record.rolcanlogin
          OR role_record.rolsuper
          OR role_record.rolcreatedb
          OR role_record.rolcreaterole
          OR role_record.rolreplication
          OR role_record.rolbypassrls
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A canonical review role has prohibited PostgreSQL attributes',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_auth_members AS membership_record
    JOIN pg_roles AS granted_role
      ON granted_role.oid = membership_record.roleid
    JOIN pg_roles AS member_role
      ON member_role.oid = membership_record.member
    WHERE granted_role.rolname IN (
        'issp_read_only_investigator',
        'issp_audit_reader',
        'issp_validation_reader'
    )
       OR member_role.rolname IN (
        'issp_read_only_investigator',
        'issp_audit_reader',
        'issp_validation_reader'
    );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'Canonical review roles must have no standing memberships',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;
END;
$validate_review_roles$;

DO $validate_review_contract_grants$
DECLARE
    v_violation_count bigint;
BEGIN
    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.review_privilege_contract AS privilege_contract
    WHERE CASE
        WHEN privilege_contract.object_kind <> 'DATABASE' THEN false
        ELSE NOT pg_catalog.has_database_privilege(
            privilege_contract.grantee_role_name,
            privilege_contract.object_identity,
            privilege_contract.privilege_type
        )
    END;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more approved review database grants are missing',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.review_privilege_contract AS privilege_contract
    WHERE CASE
        WHEN privilege_contract.object_kind <> 'SCHEMA' THEN false
        WHEN pg_catalog.to_regnamespace(
            privilege_contract.object_identity
        ) IS NULL THEN true
        ELSE NOT pg_catalog.has_schema_privilege(
            privilege_contract.grantee_role_name,
            pg_catalog.to_regnamespace(
                privilege_contract.object_identity
            ),
            privilege_contract.privilege_type
        )
    END;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more approved review schema grants are missing',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM deployment_meta.review_privilege_contract AS privilege_contract
    WHERE CASE
        WHEN privilege_contract.object_kind <> 'VIEW' THEN false
        WHEN pg_catalog.to_regclass(
            privilege_contract.object_identity
        ) IS NULL THEN true
        ELSE NOT pg_catalog.has_table_privilege(
            privilege_contract.grantee_role_name,
            pg_catalog.to_regclass(
                privilege_contract.object_identity
            ),
            privilege_contract.privilege_type
        )
    END;

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'One or more approved review view grants are missing',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;
END;
$validate_review_contract_grants$;

DO $validate_review_denials$
DECLARE
    v_violation_count bigint;
BEGIN
    SELECT count(*)
    INTO v_violation_count
    FROM (
        VALUES
            ('issp_read_only_investigator'::name),
            ('issp_audit_reader'::name),
            ('issp_validation_reader'::name)
    ) AS review_role(role_name)
    WHERE pg_catalog.has_database_privilege(
        review_role.role_name,
        current_database(),
        'TEMPORARY'
    );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A review role received database TEMPORARY privilege',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM (
        VALUES
            ('issp_read_only_investigator'::name),
            ('issp_audit_reader'::name),
            ('issp_validation_reader'::name)
    ) AS review_role(role_name)
    CROSS JOIN pg_namespace AS namespace_record
    WHERE namespace_record.nspname IN (
        'extensions',
        'deployment_meta',
        'foundation_meta',
        'trust',
        'identity',
        'organization',
        'service',
        'attestation',
        'approval',
        'access_control',
        'decision',
        'governance',
        'compliance',
        'risk',
        'resilience',
        'performance',
        'observability',
        'integration',
        'security_validation',
        'security_review'
    )
      AND pg_catalog.has_schema_privilege(
          review_role.role_name,
          namespace_record.oid,
          'CREATE'
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A review role received schema CREATE privilege',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM (
        VALUES
            ('issp_read_only_investigator'::name),
            ('issp_audit_reader'::name),
            ('issp_validation_reader'::name)
    ) AS review_role(role_name)
    CROSS JOIN pg_class AS relation_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = relation_record.relnamespace
    WHERE namespace_record.nspname IN (
        'deployment_meta',
        'foundation_meta',
        'trust',
        'identity',
        'organization',
        'service',
        'attestation',
        'approval',
        'access_control',
        'decision',
        'governance',
        'compliance',
        'risk',
        'resilience',
        'performance',
        'observability',
        'integration'
    )
      AND relation_record.relkind IN ('r', 'p', 'f')
      AND (
          pg_catalog.has_table_privilege(
              review_role.role_name,
              relation_record.oid,
              'SELECT'
          )
          OR pg_catalog.has_table_privilege(
              review_role.role_name,
              relation_record.oid,
              'INSERT'
          )
          OR pg_catalog.has_table_privilege(
              review_role.role_name,
              relation_record.oid,
              'UPDATE'
          )
          OR pg_catalog.has_table_privilege(
              review_role.role_name,
              relation_record.oid,
              'DELETE'
          )
          OR pg_catalog.has_table_privilege(
              review_role.role_name,
              relation_record.oid,
              'TRUNCATE'
          )
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A review role received direct protected base-table privileges',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM (
        VALUES
            ('issp_read_only_investigator'::name),
            ('issp_audit_reader'::name),
            ('issp_validation_reader'::name)
    ) AS review_role(role_name)
    CROSS JOIN pg_class AS sequence_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = sequence_record.relnamespace
    WHERE sequence_record.relkind = 'S'
      AND namespace_record.nspname IN (
          'deployment_meta',
          'foundation_meta',
          'trust',
          'identity',
          'organization',
          'service',
          'attestation',
          'approval',
          'access_control',
          'decision',
          'governance',
          'compliance',
          'risk',
          'resilience',
          'performance',
          'observability',
          'integration'
      )
      AND (
          pg_catalog.has_sequence_privilege(
              review_role.role_name,
              sequence_record.oid,
              'USAGE'
          )
          OR pg_catalog.has_sequence_privilege(
              review_role.role_name,
              sequence_record.oid,
              'SELECT'
          )
          OR pg_catalog.has_sequence_privilege(
              review_role.role_name,
              sequence_record.oid,
              'UPDATE'
          )
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A review role received protected sequence privileges',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM (
        VALUES
            ('issp_read_only_investigator'::name),
            ('issp_audit_reader'::name),
            ('issp_validation_reader'::name)
    ) AS review_role(role_name)
    CROSS JOIN pg_proc AS routine_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = routine_record.pronamespace
    WHERE namespace_record.nspname IN (
        'deployment_meta',
        'foundation_meta',
        'trust',
        'identity',
        'organization',
        'service',
        'attestation',
        'approval',
        'access_control',
        'decision',
        'governance',
        'compliance',
        'risk',
        'resilience',
        'performance',
        'observability',
        'integration'
    )
      AND pg_catalog.has_function_privilege(
          review_role.role_name,
          routine_record.oid,
          'EXECUTE'
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A review role received protected routine EXECUTE privilege',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;
END;
$validate_review_denials$;

DO $validate_review_view_posture$
DECLARE
    v_violation_count bigint;
BEGIN
    SELECT count(*)
    INTO v_violation_count
    FROM pg_class AS view_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = view_record.relnamespace
    WHERE (
        namespace_record.nspname = 'security_review'
        OR (
            namespace_record.nspname = 'deployment_meta'
            AND view_record.relname IN (
                'deployment_migration_status',
                'canonical_role_posture',
                'canonical_membership_posture',
                'review_privilege_contract_summary'
            )
        )
    )
      AND (
          view_record.relkind <> 'v'
          OR NOT ('security_barrier=true' = ANY(
              COALESCE(view_record.reloptions, ARRAY[]::text[])
          ))
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'An approved review surface is not a security-barrier view',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_class AS view_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = view_record.relnamespace
    WHERE namespace_record.nspname = 'security_review'
      AND pg_catalog.pg_get_userbyid(view_record.relowner) <>
          'issp_foundation_owner';

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A security_review view is not owned by issp_foundation_owner',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM pg_class AS view_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = view_record.relnamespace
    WHERE namespace_record.nspname = 'deployment_meta'
      AND view_record.relname IN (
          'deployment_migration_status',
          'canonical_role_posture',
          'canonical_membership_posture',
          'review_privilege_contract_summary'
      )
      AND pg_catalog.pg_get_userbyid(view_record.relowner) <>
          'issp_database_owner';

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'A deployment posture view is not owned by issp_database_owner',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM information_schema.columns AS column_record
    WHERE column_record.table_schema = 'security_review'
      AND column_record.table_name IN (
          'investigator_decision_summary',
          'investigator_approval_summary'
      )
      AND column_record.column_name IN (
          'requester_identity_id',
          'requester_organization_id',
          'directly_affected_identity_id',
          'device_id',
          'session_id',
          'authentication_assertion_id',
          'authorization_lease_id',
          'protected_target_reference',
          'context_snapshot',
          'record_hash',
          'record_hash_hex',
          'previous_record_hash',
          'previous_record_hash_hex'
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'An investigator view exposes a prohibited direct-identifier or raw-context column',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;

    SELECT count(*)
    INTO v_violation_count
    FROM information_schema.columns AS column_record
    WHERE column_record.table_schema = 'security_review'
      AND column_record.table_name LIKE 'audit_%'
      AND column_record.column_name IN (
          'lease_secret_hash',
          'context_snapshot',
          'supporting_context',
          'details',
          'payload',
          'signature_value',
          'nonce_hash'
      );

    IF v_violation_count <> 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = 'integrity_constraint_violation',
            MESSAGE = 'An audit view exposes prohibited secret or raw-context material',
            DETAIL = format('violation_count=%s', v_violation_count);
    END IF;
END;
$validate_review_view_posture$;

REVOKE ALL PRIVILEGES ON TABLE deployment_meta.review_privilege_contract
    FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA security_review
    FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA security_review
    FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA security_review
    FROM PUBLIC;

SELECT deployment_meta.register_deployment_migration(
    p_migration_id =>
        '930_investigator_audit_and_validation_review_surfaces',
    p_migration_name =>
        'Investigator, audit, and validation review surfaces',
    p_migration_checksum => :'deployment_migration_checksum',
    p_relative_path => :'deployment_migration_relative_path',
    p_notes =>
        'Created exact view-only review contracts for reduced-disclosure investigation, audit lineage, and deployment/Foundation validation posture.'
);

COMMIT;
