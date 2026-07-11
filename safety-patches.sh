#!/usr/bin/env bash
#
# Public Safety Platform
# Phase -1 Foundation baseline-integrity updater
#
# Run from the repository root:
#
#   chmod +x phase-minus1-foundation-integrity.sh
#   ./phase-minus1-foundation-integrity.sh
#
# By default, the script:
#   1. Verifies the expected repository layout.
#   2. Refuses to overwrite uncommitted changes in the target files.
#   3. Creates a timestamped backup archive in /tmp.
#   4. Updates migrations 000, 010, 020, 025, 030, 035, 040, 045, and 075.
#   5. Adds 080_foundation_baseline_integrity.sql.
#   6. Adds the test to foundation-tests.manifest.
#   7. Runs the full Foundation SQL test framework.
#
# Options:
#   --allow-dirty   Permit target files that already have uncommitted changes.
#   --no-tests      Update the files without running the SQL test framework.
#   --help          Show usage.
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 077

allow_dirty=0
run_tests=1

usage() {
    cat <<'USAGE'
Usage:
  ./phase-minus1-foundation-integrity.sh [options]

Options:
  --allow-dirty
      Permit updates when one or more target files already have uncommitted
      changes. A backup is still created before modification.

  --no-tests
      Do not run the Foundation SQL test framework after updating the files.

  -h, --help
      Show this help text.

Run this script from the public-safety-platform repository root.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --allow-dirty)
            allow_dirty=1
            shift
            ;;
        --no-tests)
            run_tests=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 69
    fi
}

for command_name in git python3 tar date; do
    require_command "$command_name"
done

repo_root="$(pwd -P)"

if [[ ! -d "${repo_root}/.git" ]]; then
    printf 'Run this script from the Git repository root.\n' >&2
    exit 64
fi

remote_origin="$(git config --get remote.origin.url 2>/dev/null || true)"

if [[ -n "$remote_origin" ]]; then
    case "$remote_origin" in
        *kb2vhn/public-safety-platform|*kb2vhn/public-safety-platform.git)
            ;;
        *)
            printf 'Unexpected Git repository remote: %s\n' "$remote_origin" >&2
            printf 'Expected repository: kb2vhn/public-safety-platform\n' >&2
            exit 64
            ;;
    esac
fi

migration_dir="sql/schema/migrations/foundation"
test_dir="sql/test-framework/sql/tests"
foundation_test_dir="${test_dir}/foundation"
test_manifest="${test_dir}/foundation-tests.manifest"

target_files=(
    "${migration_dir}/000_platform_initialization.sql"
    "${migration_dir}/010_cryptographic_and_device_trust.sql"
    "${migration_dir}/020_identity.sql"
    "${migration_dir}/025_identity_lifecycle.sql"
    "${migration_dir}/030_organizations_and_jurisdictions.sql"
    "${migration_dir}/035_platform_services_and_configuration.sql"
    "${migration_dir}/040_service_participation_and_federation.sql"
    "${migration_dir}/045_attestations_and_access_eligibility.sql"
    "${migration_dir}/075_controlled_authorization_api.sql"
    "${test_manifest}"
)

for target_file in "${target_files[@]}"; do
    if [[ ! -f "$target_file" ]]; then
        printf 'Expected file not found: %s\n' "$target_file" >&2
        exit 66
    fi
done

if [[ "$allow_dirty" -ne 1 ]]; then
    dirty_targets="$(
        git status --porcelain -- "${target_files[@]}"
    )"

    if [[ -n "$dirty_targets" ]]; then
        printf 'Refusing to overwrite target files with uncommitted changes:\n\n' >&2
        printf '%s\n\n' "$dirty_targets" >&2
        printf 'Commit or stash the changes, or rerun with --allow-dirty.\n' >&2
        exit 65
    fi
fi

timestamp="$(date +%Y%m%d_%H%M%S)"
backup_archive="/tmp/public-safety-platform-phase-minus1-${timestamp}.tar.gz"

printf 'Creating backup: %s\n' "$backup_archive"
tar -czf "$backup_archive" -- "${target_files[@]}"

export PSP_PHASE_MINUS1_REPO_ROOT="$repo_root"

python3 <<'PYTHON'
from __future__ import annotations

import os
from pathlib import Path

root = Path(os.environ["PSP_PHASE_MINUS1_REPO_ROOT"])

migration_dir = root / "sql/schema/migrations/foundation"
test_dir = root / "sql/test-framework/sql/tests"
foundation_test_dir = test_dir / "foundation"
manifest_path = test_dir / "foundation-tests.manifest"

TAG = "-- Phase -1 Foundation baseline integrity"


class PatchError(RuntimeError):
    pass


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write(path: Path, text: str) -> None:
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8")


def insert_before_registration(path: Path, block: str) -> None:
    text = read(path)

    if TAG in text:
        print(f"Already updated: {path.relative_to(root)}")
        return

    marker = "SELECT foundation_meta.register_migration("

    if text.count(marker) != 1:
        raise PatchError(
            f"{path.relative_to(root)}: expected exactly one migration "
            f"registration marker, found {text.count(marker)}"
        )

    normalized_block = "\n" + block.strip() + "\n\n"
    text = text.replace(marker, normalized_block + marker, 1)
    write(path, text)
    print(f"Updated: {path.relative_to(root)}")


def replace_once(path: Path, old: str, new: str, description: str) -> None:
    text = read(path)

    if new in text and old not in text:
        print(f"Already updated: {path.relative_to(root)} ({description})")
        return

    count = text.count(old)
    if count != 1:
        raise PatchError(
            f"{path.relative_to(root)}: expected one occurrence for "
            f"{description}, found {count}"
        )

    write(path, text.replace(old, new, 1))
    print(f"Updated: {path.relative_to(root)} ({description})")


insert_before_registration(
    migration_dir / "000_platform_initialization.sql",
    r'''
-- Phase -1 Foundation baseline integrity
-- CREATE EXTENSION IF NOT EXISTS does not move an extension that was already
-- installed in another schema. Verify the required extension boundary here.
DO $pgcrypto_schema_check$
DECLARE
    v_pgcrypto_schema name;
BEGIN
    SELECT namespace_record.nspname
    INTO v_pgcrypto_schema
    FROM pg_extension AS extension_record
    JOIN pg_namespace AS namespace_record
      ON namespace_record.oid = extension_record.extnamespace
    WHERE extension_record.extname = 'pgcrypto';

    IF v_pgcrypto_schema IS NULL THEN
        RAISE EXCEPTION
        USING
            ERRCODE = 'undefined_object',
            MESSAGE = 'Required pgcrypto extension is not installed';
    END IF;

    IF v_pgcrypto_schema <> 'extensions' THEN
        RAISE EXCEPTION
        USING
            ERRCODE = 'object_not_in_prerequisite_state',
            MESSAGE = 'pgcrypto must be installed in the extensions schema',
            DETAIL = format(
                'pgcrypto is currently installed in schema %I.',
                v_pgcrypto_schema
            ),
            HINT = 'Move pgcrypto with: ALTER EXTENSION pgcrypto SET SCHEMA extensions;';
    END IF;
END;
$pgcrypto_schema_check$;
''',
)

insert_before_registration(
    migration_dir / "010_cryptographic_and_device_trust.sql",
    r'''
-- Phase -1 Foundation baseline integrity

ALTER TABLE trust.certificate_authorities
    ADD CONSTRAINT ca_public_key_size_positive_ck
    CHECK (
        public_key_size_bits IS NULL
        OR public_key_size_bits > 0
    );

ALTER TABLE trust.device_certificates
    ADD CONSTRAINT device_cert_public_key_size_positive_ck
    CHECK (
        public_key_size_bits IS NULL
        OR public_key_size_bits > 0
    ),
    ADD CONSTRAINT device_cert_observation_period_ck
    CHECK (
        last_seen_at IS NULL
        OR (
            first_seen_at IS NOT NULL
            AND last_seen_at >= first_seen_at
        )
    );

ALTER TABLE trust.revocations
    ADD CONSTRAINT revocations_type_target_ck
    CHECK (
        (
            object_type = 'TRUST_PROVIDER'
            AND trust_provider_id IS NOT NULL
            AND num_nonnulls(
                certificate_authority_id,
                device_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'CERTIFICATE_AUTHORITY'
            AND certificate_authority_id IS NOT NULL
            AND num_nonnulls(
                trust_provider_id,
                device_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'DEVICE'
            AND device_id IS NOT NULL
            AND num_nonnulls(
                trust_provider_id,
                certificate_authority_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'DEVICE_CERTIFICATE'
            AND device_certificate_id IS NOT NULL
            AND num_nonnulls(
                trust_provider_id,
                certificate_authority_id,
                device_id
            ) = 0
        )
    );

ALTER TABLE trust.trust_lifecycle_events
    ADD COLUMN trust_provider_id uuid
        REFERENCES trust.trust_providers(trust_provider_id),
    ADD COLUMN certificate_authority_id uuid
        REFERENCES trust.certificate_authorities(certificate_authority_id),
    ADD COLUMN device_id uuid
        REFERENCES trust.devices(device_id),
    ADD COLUMN device_certificate_id uuid
        REFERENCES trust.device_certificates(device_certificate_id),
    ADD CONSTRAINT trust_lifecycle_type_target_ck
    CHECK (
        (
            object_type = 'TRUST_PROVIDER'
            AND trust_provider_id IS NOT NULL
            AND object_id = trust_provider_id
            AND num_nonnulls(
                certificate_authority_id,
                device_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'CERTIFICATE_AUTHORITY'
            AND certificate_authority_id IS NOT NULL
            AND object_id = certificate_authority_id
            AND num_nonnulls(
                trust_provider_id,
                device_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'DEVICE'
            AND device_id IS NOT NULL
            AND object_id = device_id
            AND num_nonnulls(
                trust_provider_id,
                certificate_authority_id,
                device_certificate_id
            ) = 0
        )
        OR
        (
            object_type = 'DEVICE_CERTIFICATE'
            AND device_certificate_id IS NOT NULL
            AND object_id = device_certificate_id
            AND num_nonnulls(
                trust_provider_id,
                certificate_authority_id,
                device_id
            ) = 0
        )
    ),
    ADD CONSTRAINT trust_lifecycle_event_type_nonempty_ck
    CHECK (btrim(event_type) <> ''),
    ADD CONSTRAINT trust_lifecycle_new_status_nonempty_ck
    CHECK (btrim(new_status) <> ''),
    ADD CONSTRAINT trust_lifecycle_reason_code_nonempty_ck
    CHECK (btrim(reason_code) <> '');

CREATE INDEX trust_revocations_provider_idx
    ON trust.revocations(trust_provider_id, effective_at)
    WHERE trust_provider_id IS NOT NULL;

CREATE INDEX trust_revocations_ca_idx
    ON trust.revocations(certificate_authority_id, effective_at)
    WHERE certificate_authority_id IS NOT NULL;
''',
)

insert_before_registration(
    migration_dir / "020_identity.sql",
    r'''
-- Phase -1 Foundation baseline integrity

ALTER TABLE identity.identities
    DROP CONSTRAINT identities_subject_ck,
    ADD CONSTRAINT identities_subject_ck
    CHECK (
        (
            identity_type = 'HUMAN'
            AND person_id IS NOT NULL
            AND service_device_id IS NULL
        )
        OR
        (
            identity_type = 'DEVICE'
            AND person_id IS NULL
            AND service_device_id IS NOT NULL
        )
        OR
        (
            identity_type IN ('SERVICE', 'WORKLOAD')
            AND person_id IS NULL
        )
    ),
    ADD CONSTRAINT identities_id_person_uq
    UNIQUE (identity_id, person_id);

COMMENT ON COLUMN identity.identities.service_device_id IS
    'Device subject for DEVICE identities and an optional execution-device reference for SERVICE or WORKLOAD identities. A future stable baseline may rename this column after runtime subject semantics are finalized.';

ALTER TABLE identity.provider_identity_mappings
    ADD CONSTRAINT provider_mapping_subject_nonempty_ck
    CHECK (btrim(provider_subject) <> '');

DO $remove_original_provider_mapping_unique$
DECLARE
    v_constraint_name name;
BEGIN
    SELECT constraint_record.conname
    INTO v_constraint_name
    FROM pg_constraint AS constraint_record
    WHERE constraint_record.conrelid =
        'identity.provider_identity_mappings'::regclass
      AND constraint_record.contype = 'u'
      AND pg_get_constraintdef(constraint_record.oid) =
        'UNIQUE (trust_provider_id, provider_subject)';

    IF v_constraint_name IS NULL THEN
        RAISE EXCEPTION
        USING
            ERRCODE = 'undefined_object',
            MESSAGE = 'Expected provider identity mapping unique constraint was not found';
    END IF;

    EXECUTE format(
        'ALTER TABLE identity.provider_identity_mappings DROP CONSTRAINT %I',
        v_constraint_name
    );
END;
$remove_original_provider_mapping_unique$;

ALTER TABLE identity.provider_identity_mappings
    ADD CONSTRAINT provider_mapping_history_uq
    UNIQUE (
        trust_provider_id,
        provider_subject,
        valid_from
    );

CREATE UNIQUE INDEX provider_identity_mappings_current_uq
    ON identity.provider_identity_mappings(
        trust_provider_id,
        provider_subject
    )
    WHERE
        valid_until IS NULL
        AND status IN ('ACTIVE', 'SUSPENDED');
''',
)

insert_before_registration(
    migration_dir / "025_identity_lifecycle.sql",
    r'''
-- Phase -1 Foundation baseline integrity

ALTER TABLE identity.identity_lifecycle_events
    ADD CONSTRAINT identity_lifecycle_event_type_nonempty_ck
    CHECK (btrim(event_type) <> ''),
    ADD CONSTRAINT identity_lifecycle_previous_status_ck
    CHECK (
        previous_status IS NULL
        OR previous_status IN (
            'PENDING',
            'ACTIVE',
            'SUSPENDED',
            'DISABLED',
            'RETIRED',
            'ARCHIVED'
        )
    ),
    ADD CONSTRAINT identity_lifecycle_new_status_ck
    CHECK (
        new_status IN (
            'PENDING',
            'ACTIVE',
            'SUSPENDED',
            'DISABLED',
            'RETIRED',
            'ARCHIVED'
        )
    ),
    ADD CONSTRAINT identity_lifecycle_reason_code_nonempty_ck
    CHECK (btrim(reason_code) <> '');

ALTER TABLE identity.identity_suspensions
    ADD CONSTRAINT identity_suspension_reason_code_nonempty_ck
    CHECK (btrim(reason_code) <> ''),
    ADD CONSTRAINT identity_suspension_release_period_ck
    CHECK (
        released_at IS NULL
        OR released_at >= effective_at
    );
''',
)

insert_before_registration(
    migration_dir / "030_organizations_and_jurisdictions.sql",
    r'''
-- Phase -1 Foundation baseline integrity

ALTER TABLE organization.organizations
    ADD CONSTRAINT organizations_key_format_ck
    CHECK (organization_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT organizations_type_nonempty_ck
    CHECK (btrim(organization_type) <> '');

ALTER TABLE organization.organizational_units
    ADD CONSTRAINT organizational_units_org_id_unit_id_uq
    UNIQUE (organization_id, organizational_unit_id),
    ADD CONSTRAINT organizational_units_key_format_ck
    CHECK (unit_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT organizational_units_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT organizational_units_parent_not_self_ck
    CHECK (
        parent_unit_id IS NULL
        OR parent_unit_id <> organizational_unit_id
    ),
    ADD CONSTRAINT organizational_units_parent_same_org_fk
    FOREIGN KEY (organization_id, parent_unit_id)
    REFERENCES organization.organizational_units(
        organization_id,
        organizational_unit_id
    );

ALTER TABLE organization.organization_relationships
    ADD CONSTRAINT organization_relationship_type_nonempty_ck
    CHECK (btrim(relationship_type) <> ''),
    ADD CONSTRAINT organization_relationship_status_nonempty_ck
    CHECK (btrim(status) <> '');

ALTER TABLE organization.jurisdictions
    ADD CONSTRAINT jurisdictions_key_format_ck
    CHECK (jurisdiction_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT jurisdictions_type_nonempty_ck
    CHECK (btrim(jurisdiction_type) <> ''),
    ADD CONSTRAINT jurisdictions_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT jurisdictions_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE organization.jurisdiction_authorities
    ADD CONSTRAINT jurisdiction_authority_purpose_nonempty_ck
    CHECK (btrim(authority_purpose) <> ''),
    ADD CONSTRAINT jurisdiction_authority_priority_positive_ck
    CHECK (priority > 0),
    ADD CONSTRAINT jurisdiction_authority_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT jurisdiction_authority_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );
''',
)

insert_before_registration(
    migration_dir / "035_platform_services_and_configuration.sql",
    r'''
-- Phase -1 Foundation baseline integrity

ALTER TABLE service.platform_services
    ADD CONSTRAINT platform_services_key_format_ck
    CHECK (service_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT platform_services_type_nonempty_ck
    CHECK (btrim(service_type) <> ''),
    ADD CONSTRAINT platform_services_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT platform_services_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE service.deployments
    ADD CONSTRAINT deployments_key_format_ck
    CHECK (deployment_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT deployments_environment_key_format_ck
    CHECK (environment_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT deployments_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT deployments_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE service.configuration_items
    ADD COLUMN configuration_scope text NOT NULL,
    ADD CONSTRAINT configuration_items_scope_ck
    CHECK (
        (
            configuration_scope = 'PLATFORM'
            AND service_id IS NULL
            AND deployment_id IS NULL
        )
        OR
        (
            configuration_scope = 'SERVICE'
            AND service_id IS NOT NULL
            AND deployment_id IS NULL
        )
        OR
        (
            configuration_scope = 'DEPLOYMENT'
            AND service_id IS NULL
            AND deployment_id IS NOT NULL
        )
    ),
    ADD CONSTRAINT configuration_items_key_format_ck
    CHECK (configuration_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT configuration_items_classification_nonempty_ck
    CHECK (
        classification_key IS NULL
        OR btrim(classification_key) <> ''
    ),
    ADD CONSTRAINT configuration_items_version_positive_ck
    CHECK (version_number > 0),
    ADD CONSTRAINT configuration_items_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

CREATE UNIQUE INDEX configuration_items_platform_version_uq
    ON service.configuration_items(
        configuration_key,
        version_number
    )
    WHERE configuration_scope = 'PLATFORM';

CREATE UNIQUE INDEX configuration_items_service_version_uq
    ON service.configuration_items(
        service_id,
        configuration_key,
        version_number
    )
    WHERE configuration_scope = 'SERVICE';

CREATE UNIQUE INDEX configuration_items_deployment_version_uq
    ON service.configuration_items(
        deployment_id,
        configuration_key,
        version_number
    )
    WHERE configuration_scope = 'DEPLOYMENT';
''',
)

insert_before_registration(
    migration_dir / "040_service_participation_and_federation.sql",
    r'''
-- Phase -1 Foundation baseline integrity

ALTER TABLE service.participation_agreements
    ADD COLUMN version_number integer NOT NULL DEFAULT 1,
    ADD CONSTRAINT participation_agreements_key_format_ck
    CHECK (agreement_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT participation_agreements_version_positive_ck
    CHECK (version_number > 0),
    ADD CONSTRAINT participation_agreements_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT participation_agreements_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

DO $remove_original_participation_agreement_unique$
DECLARE
    v_constraint_name name;
BEGIN
    SELECT constraint_record.conname
    INTO v_constraint_name
    FROM pg_constraint AS constraint_record
    WHERE constraint_record.conrelid =
        'service.participation_agreements'::regclass
      AND constraint_record.contype = 'u'
      AND pg_get_constraintdef(constraint_record.oid) =
        'UNIQUE (service_id, participating_organization_id, agreement_key)';

    IF v_constraint_name IS NULL THEN
        RAISE EXCEPTION
        USING
            ERRCODE = 'undefined_object',
            MESSAGE = 'Expected participation agreement unique constraint was not found';
    END IF;

    EXECUTE format(
        'ALTER TABLE service.participation_agreements DROP CONSTRAINT %I',
        v_constraint_name
    );
END;
$remove_original_participation_agreement_unique$;

ALTER TABLE service.participation_agreements
    ADD CONSTRAINT participation_agreements_version_uq
    UNIQUE (
        service_id,
        participating_organization_id,
        agreement_key,
        version_number
    );

ALTER TABLE service.participation_scopes
    ADD CONSTRAINT participation_scopes_type_nonempty_ck
    CHECK (btrim(scope_type) <> ''),
    ADD CONSTRAINT participation_scopes_reference_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT participation_scopes_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE service.delegated_authorities
    ADD CONSTRAINT delegated_authorities_no_self_ck
    CHECK (
        delegating_organization_id <> receiving_organization_id
    ),
    ADD CONSTRAINT delegated_authorities_category_nonempty_ck
    CHECK (btrim(authority_category) <> ''),
    ADD CONSTRAINT delegated_authorities_scope_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT delegated_authorities_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT delegated_authorities_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );
''',
)

insert_before_registration(
    migration_dir / "045_attestations_and_access_eligibility.sql",
    r'''
-- Phase -1 Foundation baseline integrity

ALTER TABLE attestation.attestation_authorities
    ADD CONSTRAINT attestation_authorities_category_nonempty_ck
    CHECK (btrim(authority_category) <> ''),
    ADD CONSTRAINT attestation_authorities_scope_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT attestation_authorities_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT attestation_authorities_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    );

ALTER TABLE attestation.organizational_attestations
    ADD CONSTRAINT organizational_attestations_identity_person_fk
    FOREIGN KEY (subject_identity_id, subject_person_id)
    REFERENCES identity.identities(identity_id, person_id),
    ADD CONSTRAINT organizational_attestations_category_nonempty_ck
    CHECK (btrim(attestation_category) <> ''),
    ADD CONSTRAINT organizational_attestations_scope_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT organizational_attestations_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT organizational_attestations_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    ),
    ADD CONSTRAINT organizational_attestations_review_ck
    CHECK (
        review_at IS NULL
        OR review_at >= valid_from
    );

ALTER TABLE attestation.access_eligibility_grants
    ADD CONSTRAINT access_eligibility_identity_person_fk
    FOREIGN KEY (identity_id, person_id)
    REFERENCES identity.identities(identity_id, person_id),
    ADD CONSTRAINT access_eligibility_key_format_ck
    CHECK (eligibility_key ~ '^[a-z][a-z0-9_.-]*$'),
    ADD CONSTRAINT access_eligibility_scope_nonempty_ck
    CHECK (btrim(scope_reference) <> ''),
    ADD CONSTRAINT access_eligibility_status_nonempty_ck
    CHECK (btrim(status) <> ''),
    ADD CONSTRAINT access_eligibility_validity_ck
    CHECK (
        valid_until IS NULL
        OR valid_until > valid_from
    ),
    ADD CONSTRAINT access_eligibility_review_ck
    CHECK (
        review_at IS NULL
        OR review_at >= valid_from
    );

CREATE INDEX access_eligibility_current_lookup_idx
    ON attestation.access_eligibility_grants(
        identity_id,
        service_id,
        participating_organization_id,
        status,
        valid_until
    );
''',
)

path_075 = migration_dir / "075_controlled_authorization_api.sql"

replace_once(
    path_075,
    "AND lease.issued_at <= pg_catalog.clock_timestamp()",
    "AND lease.issued_at <= pg_catalog.statement_timestamp()",
    "lease issued-at statement time",
)

replace_once(
    path_075,
    "AND pg_catalog.clock_timestamp() < lease.expires_at",
    "AND pg_catalog.statement_timestamp() < lease.expires_at",
    "lease expiration statement time",
)

text_075 = read(path_075)
if TAG not in text_075:
    marker = "-- Authorization Lease verification"
    if marker not in text_075:
        raise PatchError(
            f"{path_075.relative_to(root)}: verification section marker not found"
        )
    text_075 = text_075.replace(
        marker,
        TAG
        + "\n"
        + "-- The STABLE verifier uses statement_timestamp() so one statement "
          "evaluates a lease against one authoritative time.\n\n"
        + marker,
        1,
    )
    write(path_075, text_075)

foundation_test_dir.mkdir(parents=True, exist_ok=True)
baseline_test_path = foundation_test_dir / "080_foundation_baseline_integrity.sql"

baseline_test_sql = r'''-- Phase -1 Foundation baseline integrity behavior tests.

SELECT sql_test.begin_file('080_foundation_baseline_integrity.sql');

INSERT INTO trust.trust_providers (
    trust_provider_id,
    provider_key,
    display_name,
    provider_type,
    environment_key,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '10000000-0000-0000-0000-000000000001',
    'sql_test.provider',
    'SQL Test Provider',
    'IDENTITY_PROVIDER',
    'test',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO trust.certificate_authorities (
    certificate_authority_id,
    trust_provider_id,
    authority_key,
    subject_distinguished_name,
    serial_number_hex,
    sha256_fingerprint,
    public_key_algorithm,
    public_key_size_bits,
    signature_algorithm,
    is_root_authority,
    status,
    valid_from,
    valid_until,
    created_by_reference
)
VALUES (
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'sql_test_ca',
    'CN=SQL Test CA',
    '01',
    repeat('a', 64),
    'RSA',
    4096,
    'SHA256-RSA',
    true,
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '365 days',
    'sql-test'
);

INSERT INTO trust.devices (
    device_id,
    device_key,
    device_type,
    status,
    created_by_reference
)
VALUES
(
    '10000000-0000-0000-0000-000000000003',
    'sql_test.device',
    'WORKSTATION',
    'TRUSTED',
    'sql-test'
),
(
    '10000000-0000-0000-0000-000000000004',
    'sql_test.device.two',
    'WORKSTATION',
    'TRUSTED',
    'sql-test'
);

INSERT INTO trust.device_certificates (
    device_certificate_id,
    device_id,
    certificate_authority_id,
    certificate_role,
    subject_distinguished_name,
    serial_number_hex,
    sha256_fingerprint,
    public_key_algorithm,
    public_key_size_bits,
    signature_algorithm,
    status,
    valid_from,
    valid_until,
    first_seen_at,
    last_seen_at,
    created_by_reference
)
VALUES (
    '10000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000002',
    'CLIENT_AUTHENTICATION',
    'CN=SQL Test Device',
    '02',
    repeat('b', 64),
    'RSA',
    2048,
    'SHA256-RSA',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    statement_timestamp() + interval '30 days',
    statement_timestamp() - interval '1 hour',
    statement_timestamp(),
    'sql-test'
);

SELECT sql_test.assert_raises(
    'Revocation object type must match the referenced target',
    $statement$
    INSERT INTO trust.revocations (
        object_type,
        device_certificate_id,
        reason_code,
        effective_at,
        recorded_by_reference
    )
    VALUES (
        'DEVICE',
        '10000000-0000-0000-0000-000000000005',
        'SQL_TEST',
        statement_timestamp(),
        'sql-test'
    )
    $statement$,
    '23514'
);

SELECT sql_test.assert_raises(
    'Certificate authority public key size must be positive',
    $statement$
    INSERT INTO trust.certificate_authorities (
        trust_provider_id,
        authority_key,
        subject_distinguished_name,
        serial_number_hex,
        sha256_fingerprint,
        public_key_algorithm,
        public_key_size_bits,
        signature_algorithm,
        is_root_authority,
        status,
        valid_from,
        valid_until,
        created_by_reference
    )
    VALUES (
        '10000000-0000-0000-0000-000000000001',
        'invalid_key_size',
        'CN=Invalid Key Size',
        '03',
        repeat('c', 64),
        'RSA',
        0,
        'SHA256-RSA',
        false,
        'ACTIVE',
        statement_timestamp(),
        statement_timestamp() + interval '1 day',
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO identity.persons (
    person_id,
    person_key,
    display_name,
    status,
    created_by_reference
)
VALUES
(
    '20000000-0000-0000-0000-000000000001',
    'sql_test.person.one',
    'SQL Test Person One',
    'ACTIVE',
    'sql-test'
),
(
    '20000000-0000-0000-0000-000000000002',
    'sql_test.person.two',
    'SQL Test Person Two',
    'ACTIVE',
    'sql-test'
);

INSERT INTO identity.identities (
    identity_id,
    identity_key,
    identity_type,
    person_id,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000003',
    'sql_test.identity.human',
    'HUMAN',
    '20000000-0000-0000-0000-000000000001',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO identity.identities (
    identity_id,
    identity_key,
    identity_type,
    service_device_id,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000004',
    'sql_test.identity.device',
    'DEVICE',
    '10000000-0000-0000-0000-000000000003',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

SELECT sql_test.assert_raises(
    'DEVICE identity requires a device subject',
    $statement$
    INSERT INTO identity.identities (
        identity_key,
        identity_type,
        status,
        valid_from,
        created_by_reference
    )
    VALUES (
        'sql_test.identity.invalid_device',
        'DEVICE',
        'ACTIVE',
        statement_timestamp(),
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO identity.provider_identity_mappings (
    identity_id,
    trust_provider_id,
    provider_subject,
    valid_from,
    valid_until,
    status,
    created_by_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'sql-test-subject',
    statement_timestamp() - interval '10 days',
    statement_timestamp() - interval '1 day',
    'SUPERSEDED',
    'sql-test'
);

INSERT INTO identity.provider_identity_mappings (
    identity_id,
    trust_provider_id,
    provider_subject,
    valid_from,
    status,
    created_by_reference
)
VALUES (
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'sql-test-subject',
    statement_timestamp() - interval '1 day',
    'ACTIVE',
    'sql-test'
);

SELECT sql_test.assert_equal_bigint(
    'Provider identity mapping history can preserve multiple versions',
    (
        SELECT count(*)
        FROM identity.provider_identity_mappings
        WHERE trust_provider_id =
            '10000000-0000-0000-0000-000000000001'
          AND provider_subject = 'sql-test-subject'
    ),
    2
);

SELECT sql_test.assert_raises(
    'Only one current provider subject mapping may exist',
    $statement$
    INSERT INTO identity.provider_identity_mappings (
        identity_id,
        trust_provider_id,
        provider_subject,
        valid_from,
        status,
        created_by_reference
    )
    VALUES (
        '20000000-0000-0000-0000-000000000003',
        '10000000-0000-0000-0000-000000000001',
        'sql-test-subject',
        statement_timestamp(),
        'ACTIVE',
        'sql-test'
    )
    $statement$,
    '23505'
);

SELECT sql_test.assert_raises(
    'Identity suspension release cannot precede its effective time',
    $statement$
    INSERT INTO identity.identity_suspensions (
        identity_id,
        reason_code,
        effective_at,
        released_at,
        recorded_by_reference
    )
    VALUES (
        '20000000-0000-0000-0000-000000000003',
        'SQL_TEST',
        statement_timestamp(),
        statement_timestamp() - interval '1 hour',
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO organization.organizations (
    organization_id,
    organization_key,
    legal_name,
    display_name,
    organization_type,
    status,
    valid_from,
    created_by_reference
)
VALUES
(
    '30000000-0000-0000-0000-000000000001',
    'sql_test.organization.one',
    'SQL Test Organization One',
    'SQL Test Organization One',
    'TEST',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
),
(
    '30000000-0000-0000-0000-000000000002',
    'sql_test.organization.two',
    'SQL Test Organization Two',
    'SQL Test Organization Two',
    'TEST',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO organization.organizational_units (
    organizational_unit_id,
    organization_id,
    unit_key,
    display_name,
    status,
    valid_from
)
VALUES (
    '30000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',
    'parent',
    'Parent Unit',
    'ACTIVE',
    statement_timestamp() - interval '1 day'
);

SELECT sql_test.assert_raises(
    'Organizational unit parent must belong to the same organization',
    $statement$
    INSERT INTO organization.organizational_units (
        organization_id,
        parent_unit_id,
        unit_key,
        display_name,
        status,
        valid_from
    )
    VALUES (
        '30000000-0000-0000-0000-000000000002',
        '30000000-0000-0000-0000-000000000003',
        'invalid_child',
        'Invalid Child',
        'ACTIVE',
        statement_timestamp()
    )
    $statement$,
    '23503'
);

INSERT INTO service.platform_services (
    service_id,
    service_key,
    display_name,
    service_type,
    service_owner_organization_id,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '40000000-0000-0000-0000-000000000001',
    'sql_test.service',
    'SQL Test Service',
    'TEST',
    '30000000-0000-0000-0000-000000000001',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

INSERT INTO service.deployments (
    deployment_id,
    service_id,
    deployment_key,
    environment_key,
    platform_operator_organization_id,
    status,
    valid_from
)
VALUES (
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000001',
    'test',
    'test',
    '30000000-0000-0000-0000-000000000001',
    'ACTIVE',
    statement_timestamp() - interval '1 day'
);

SELECT sql_test.assert_raises(
    'Configuration scope cannot identify both service and deployment',
    $statement$
    INSERT INTO service.configuration_items (
        service_id,
        deployment_id,
        configuration_scope,
        configuration_key,
        configuration_value,
        version_number,
        valid_from,
        approved_by_reference
    )
    VALUES (
        '40000000-0000-0000-0000-000000000001',
        '40000000-0000-0000-0000-000000000002',
        'SERVICE',
        'sql_test.invalid_scope',
        '{}'::jsonb,
        1,
        statement_timestamp(),
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO service.participation_agreements (
    service_id,
    participating_organization_id,
    service_owner_organization_id,
    platform_operator_organization_id,
    agreement_key,
    version_number,
    status,
    valid_from,
    valid_until,
    governing_document_reference,
    governing_document_version,
    created_by_reference
)
VALUES
(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'sql_test_agreement',
    1,
    'SUPERSEDED',
    statement_timestamp() - interval '10 days',
    statement_timestamp() - interval '1 day',
    'sql-test-document',
    '1',
    'sql-test'
),
(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'sql_test_agreement',
    2,
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    NULL,
    'sql-test-document',
    '2',
    'sql-test'
);

SELECT sql_test.assert_equal_bigint(
    'Participation agreement history can preserve multiple versions',
    (
        SELECT count(*)
        FROM service.participation_agreements
        WHERE service_id =
            '40000000-0000-0000-0000-000000000001'
          AND participating_organization_id =
            '30000000-0000-0000-0000-000000000002'
          AND agreement_key = 'sql_test_agreement'
    ),
    2
);

SELECT sql_test.assert_raises(
    'An organization cannot delegate authority to itself',
    $statement$
    INSERT INTO service.delegated_authorities (
        delegating_organization_id,
        receiving_organization_id,
        service_id,
        authority_category,
        scope_reference,
        status,
        valid_from,
        created_by_reference
    )
    VALUES (
        '30000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001',
        '40000000-0000-0000-0000-000000000001',
        'TEST',
        'sql-test',
        'ACTIVE',
        statement_timestamp(),
        'sql-test'
    )
    $statement$,
    '23514'
);

INSERT INTO attestation.attestation_authorities (
    attestation_authority_id,
    authority_category,
    authorizing_organization_id,
    attesting_organization_id,
    service_id,
    authorized_identity_id,
    scope_reference,
    status,
    valid_from,
    created_by_reference
)
VALUES (
    '50000000-0000-0000-0000-000000000001',
    'TEST',
    '30000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000003',
    'sql-test',
    'ACTIVE',
    statement_timestamp() - interval '1 day',
    'sql-test'
);

SELECT sql_test.assert_raises(
    'Organizational attestation person must match its identity',
    $statement$
    INSERT INTO attestation.organizational_attestations (
        attestation_authority_id,
        subject_identity_id,
        subject_person_id,
        attestation_category,
        attestation_value,
        scope_reference,
        status,
        valid_from
    )
    VALUES (
        '50000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000003',
        '20000000-0000-0000-0000-000000000002',
        'TEST',
        '{}'::jsonb,
        'sql-test',
        'VALID',
        statement_timestamp()
    )
    $statement$,
    '23503'
);

SELECT sql_test.assert_true(
    'STABLE lease verification uses statement-consistent time',
    pg_get_functiondef(
        'access_control.verify_lease_secret(uuid,text)'::regprocedure
    ) LIKE '%statement_timestamp()%'
    AND pg_get_functiondef(
        'access_control.verify_lease_secret(uuid,text)'::regprocedure
    ) NOT LIKE '%clock_timestamp()%',
    NULL
);
'''

write(baseline_test_path, baseline_test_sql)
print(f"Created: {baseline_test_path.relative_to(root)}")

manifest_text = read(manifest_path)
manifest_entry = "foundation/080_foundation_baseline_integrity.sql"

if manifest_entry not in manifest_text.splitlines():
    if not manifest_text.endswith("\n"):
        manifest_text += "\n"
    manifest_text += manifest_entry + "\n"
    write(manifest_path, manifest_text)
    print(f"Updated: {manifest_path.relative_to(root)}")
else:
    print(f"Already updated: {manifest_path.relative_to(root)}")

expected_tags = [
    migration_dir / "000_platform_initialization.sql",
    migration_dir / "010_cryptographic_and_device_trust.sql",
    migration_dir / "020_identity.sql",
    migration_dir / "025_identity_lifecycle.sql",
    migration_dir / "030_organizations_and_jurisdictions.sql",
    migration_dir / "035_platform_services_and_configuration.sql",
    migration_dir / "040_service_participation_and_federation.sql",
    migration_dir / "045_attestations_and_access_eligibility.sql",
    migration_dir / "075_controlled_authorization_api.sql",
]

for path in expected_tags:
    if TAG not in read(path):
        raise PatchError(
            f"{path.relative_to(root)}: Phase -1 marker is missing after update"
        )

verify_body = read(path_075).split(
    "CREATE OR REPLACE FUNCTION access_control.verify_lease_secret", 1
)[1].split("$function$;", 1)[0]

if "pg_catalog.clock_timestamp()" in verify_body:
    raise PatchError(
        "verify_lease_secret still contains clock_timestamp()"
    )

print("Phase -1 source updates completed successfully.")
PYTHON

printf '\nChanged files:\n'
git status --short -- \
    "${target_files[@]}" \
    "${foundation_test_dir}/080_foundation_baseline_integrity.sql"

printf '\nDiff summary:\n'
git diff --stat -- \
    "${target_files[@]}" \
    "${foundation_test_dir}/080_foundation_baseline_integrity.sql"

if [[ "$run_tests" -eq 1 ]]; then
    printf '\nRunning the complete Foundation SQL test framework...\n\n'
    make -C sql/test-framework test-sql
else
    printf '\nTests were skipped by request.\n'
    printf 'Run them with:\n\n'
    printf '  make -C sql/test-framework test-sql\n'
fi

printf '\nPhase -1 update complete.\n'
printf 'Backup archive: %s\n' "$backup_archive"
printf '\nReview before committing:\n\n'
printf '  git diff -- sql/schema/migrations/foundation sql/test-framework/sql/tests\n'
printf '  git status\n'

