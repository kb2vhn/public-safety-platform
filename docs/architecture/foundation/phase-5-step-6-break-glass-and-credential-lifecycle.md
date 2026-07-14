# Phase 5 Step 6 — Break-Glass and Credential Lifecycle

> **Status:** Phase 5 Step 6 candidate.
>
> **Accepted predecessor:** Phase 5 Step 5 review and validation roles.
>
> **Implementation migration:**
> `sql/deployment/migrations/940_break_glass_and_credential_lifecycle.sql`

## Purpose

Implement emergency PostgreSQL access without turning the emergency identity
into a standing administrator account. The `issp_break_glass` role remains
`NOLOGIN`, has no credential, has no database `CONNECT`, and has no role
memberships at rest.

The same migration establishes explicit credential-lifecycle requirements for
the migration executor and production service identities. Credentials, private
keys, tokens, and passwords remain outside the repository and database.

## Disabled-at-Rest Boundary

At rest, `issp_break_glass` must have all of the following properties:

- `NOLOGIN`;
- `PASSWORD NULL`;
- no database `CONNECT`;
- no standing role memberships;
- no `SUPERUSER`, `CREATEDB`, `CREATEROLE`, `REPLICATION`, or `BYPASSRLS`;
- no direct protected-object privileges;
- no ordinary service, review, migration, or administrator membership path.

Migration 940 explicitly restores that posture during initial deployment and
after every controlled deactivation or expiration.

## Required Independent Actors

A break-glass request requires four attributable identities:

1. requester;
2. first approver;
3. second approver;
4. activation operator.

The requester and both approvers must be distinct. The activation operator must
also be distinct from the requester and both approvers. Database controls reject
a request or activation that violates this separation. Lifecycle transitions
also share a transaction-scoped advisory lock so concurrent request,
activation, use, deactivation, and expiration operations cannot silently race
past the current-state checks.

These identities are evidence references to the governed external identity and
approval process. They do not create PostgreSQL login roles.

## Activation Window

A request must declare a duration between 5 minutes and 1 hour. Activation must
occur within 15 minutes of request creation.

During an accepted activation, PostgreSQL grants only the temporary ability to
`SET ROLE` to:

- `issp_database_owner`;
- `issp_foundation_owner`;
- `issp_extension_owner`.

Each temporary membership uses:

```text
INHERIT FALSE
SET TRUE
ADMIN FALSE
```

The emergency role receives:

- database `CONNECT`;
- `LOGIN`;
- connection limit `1`;
- `VALID UNTIL` equal to the approved expiration;
- restrictive lock, statement, idle-transaction, and idle-session timeouts.

The role does not receive `SUPERUSER`, migration-executor membership, runtime
membership, writer membership, or role-administration authority.

## Authentication and Secret Handling

Migration 940 never accepts a plaintext password, private key, token, or secret and never writes credential material to Step 6 evidence tables.
At rest, the role remains `PASSWORD NULL`. During activation, the controlled
procedure accepts only an externally generated SCRAM-SHA-256 verifier. The
plaintext password remains in the external secret-management system and is
never written to repository files or Step 6 evidence tables.

PostgreSQL stores the verifier temporarily in `pg_authid` while the emergency
window is active. `VALID UNTIL` applies to password authentication and therefore
provides a database-enforced authentication expiration for this workflow. The
production `pg_hba.conf` entry for `issp_break_glass` must use
`scram-sha-256`; certificate, peer, trust, GSSAPI, or other non-password login
paths are prohibited for this role unless a later accepted control provides an
equivalent independent expiration boundary.

The evidence model stores only:

- an external secret-version reference;
- a lowercase SHA-256 fingerprint;
- issuance, activation, expiration, rotation, revocation, or disablement
  evidence.

The PostgreSQL host authentication policy must prevent passwordless fallback.
Host configuration is outside this migration and remains a production
deployment requirement.

A fingerprint that reached ACTIVATED cannot be reused for a later emergency.
Deactivation and expiration create `ROTATION_REQUIRED` evidence.

## Forced Deactivation and Expiration

Controlled deactivation and expiration perform all of the following:

1. terminate active `issp_break_glass` sessions;
2. revoke database `CONNECT`;
3. revoke all temporary owner-role memberships;
4. return the role to `NOLOGIN`;
5. restore connection limit `-1`;
6. retain `PASSWORD NULL`;
7. append a deactivation or expiration event;
8. require external credential rotation.

`VALID UNTIL` prevents a new authentication after expiration. The accepted
operator procedure must also invoke
`emergency_control.enforce_break_glass_expiration` on a governed schedule so
expired sessions and temporary memberships are removed promptly.

## Append-Only Evidence

Migration 940 creates append-only records for:

- break-glass requests;
- activation, use, deactivation, and expiration events;
- credential lifecycle events;
- evidence records marked `off_host_export_required`.

Update and delete operations on these records are rejected by database triggers.
The evidence outbox does not claim that off-host transport already exists. It
creates the mandatory protected evidence that the production logging process
must export and verify outside the database host.

## Review Surfaces

The audit reader receives only:

- `deployment_meta.audit_break_glass_events`;
- `deployment_meta.audit_credential_lifecycle_events`.

The validation reader receives only:

- `deployment_meta.break_glass_posture`;
- `deployment_meta.credential_lifecycle_posture`;
- `deployment_meta.break_glass_evidence_posture`.

All five are `security_barrier` views owned by `issp_database_owner`. Neither
review role receives direct access to the underlying emergency-control tables or
execution of emergency-control routines.

Runtime and service identities receive no Step 6 access.

## Credential Lifecycle Policy

The Step 6 policy contains five canonical identities:

| Role | Credential class | Maximum lifetime | Rotate after use |
|---|---|---:|---:|
| `issp_migration_executor` | Deployment | 24 hours | Yes |
| `issp_service_authorization` | Service | 90 days | No |
| `issp_service_integration_delivery` | Service | 90 days | No |
| `issp_service_monitoring_delivery` | Service | 90 days | No |
| `issp_break_glass` | Break-glass SCRAM credential | 1 hour | Yes |

Every policy requires external secret management, prohibits shared credentials,
and prohibits repository storage.

## Explicit Non-Claims

Phase 5 Step 6 does not claim:

- a production secret-management integration is deployed;
- the production SCRAM secret-generation and delivery path is configured;
- `pg_hba.conf` is production-ready;
- evidence is already exported off-host;
- operating-system or PostgreSQL-superuser governance is complete;
- backup, rebuild, or host-compromise controls are complete.

Those remain deployment-security requirements.

## Acceptance Boundary

Step 6 is accepted only when the disposable-cluster test proves:

- disabled-at-rest posture;
- distinct requester, approvers, and operator;
- bounded activation and exact temporary memberships;
- emergency connection and controlled `SET ROLE` behavior;
- denial of unrelated role transitions;
- append-only request and evidence records;
- forced deactivation and expiration;
- credential-fingerprint non-reuse;
- exact audit and validation review access;
- no runtime or service access;
- exact deployment-prefix idempotence;
- complete predecessor revalidation.

Phase 5 Step 7 may then perform hostile-condition and role-race validation.

## Step 7 Pre-Freeze Credential-Binding Hardening

Hostile-condition review found that syntax validation alone did not prove that the supplied SCRAM verifier matched the fingerprint independently approved with the request. Before formal Phase 5 acceptance, migration `940` now requires at least 4096 SCRAM iterations and compares the SHA-256 digest of the supplied verifier with the approved request fingerprint. The Step 6 disposable test derives its request fingerprints from its ephemeral verifiers so the complete Step 6 boundary is revalidated after this correction.
