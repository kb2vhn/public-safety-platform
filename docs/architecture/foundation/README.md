# Platform Foundation Documentation

> **Architecture status:** Normative and under active refinement.
>
> **SQL status:** Initial Foundation migrations `000–099` exist. Selected
> controls are database-enforced and tested; structural presence does not imply
> complete runtime, deployment, or operational enforcement.
>
> **Current status:** Phase 4 approval independence and separation of duties
> formally accepted at `phase-4-approval-independence-and-separation-of-duties-complete-v1`.

## Purpose

The Platform Foundation is a domain-neutral layer for trust, identity,
authentication inputs, sessions, authorization, approvals, accountable
Decision Records, governance, compliance, lifecycle, resilience, resource
governance, observability, and integration intent.

Potential consumers include public safety, municipal administration, finance,
human resources, records management, permitting, fleet and asset systems,
utilities, education, and future integrated services.

The Foundation does not contain CAD incidents, RMS cases, evidence custody,
payroll, procurement, Fire or EMS workflow, student records, permits, utility
accounts, or other module-owned business records.

## Non-Negotiable Principles

1. Trust must be established before protected identity or authority is
   accepted.
2. A certificate, password, MFA result, Authentication Assertion, session,
   role, approval, network location, or lease secret does not independently
   grant access.
3. Authentication establishes identity context; authorization establishes
   bounded authority.
4. Future Go services will collect typed supporting records, coordinate
   workflows, and call controlled APIs; PostgreSQL will independently
   verify selected protected operations and controlled state transitions.
5. No ordinary identity, application account, administrator, or accumulated
   role set may provide unrestricted platform authority.
6. Required decision stages fail closed on `FAIL` or `NOT_EVALUATED`.
7. Material decisions and lifecycle transitions must retain attributable,
   reviewable records.
8. Policies, agreements, controls, rules, and governed documents used in
   decisions must be versioned and integrity-verifiable.
9. Current state must not silently overwrite historical state.
10. Shared infrastructure does not create centralized organizational
    authority.
11. Authorization is bounded by identity, organization, Platform Service,
    Governed Purpose, Governed Operation, Protected Resource Target, Governed
    Scope, Data Classification, policy, and authoritative time.
12. External monitoring, integration, and delivery providers remain
    replaceable.
13. Workloads and resource consumption must be attributable and bounded.
14. Availability, recovery, degraded operation, and compromise recovery must
    be governed before production use.
15. Domain-specific concepts belong in modules; the Foundation uses neutral
    shared concepts and extension points.

## Accepted Phase 1 Boundary

Phase 1 is accepted at:

```text
phase-1-authentication-assertion-complete-v1
```

Accepted evidence:

```text
31 manifest migrations
31 registered migrations
10 sequential test files
1 concurrency test file
135 PASS
0 FAIL
3 understood WARN
```

Phase 1 established controlled local Authentication Assertion verification,
rejection, expiration, revocation, exact-context consumption, terminal-state
enforcement, and concurrent single-use behavior.

See:

- [Authentication Assertion Verification and Consumption Model](authentication-assertion-verification-and-consumption-model.md)
- [Phase 1 Authentication Assertion Acceptance](phase-1-authentication-assertion-acceptance.md)

## Accepted Phase 2 Boundary

Phase 2 is accepted at:

```text
phase-2-session-control-complete-v1
```

Accepted evidence:

```text
32 manifest migrations
32 registered migrations
12 sequential test files
4 concurrency test files
213 PASS
0 FAIL
3 understood WARN
```

Phase 2 established atomic session establishment, step-up, current-trust
revalidation, controlled activity, lock and administrative unlock, absolute
and inactivity expiration, revocation, termination, terminal-state
enforcement, same-transaction session events, and independent-connection
concurrency proofs.

See:

- [Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md)
- [Phase 2 Session Establishment, Step-Up, and Lifecycle Acceptance](phase-2-session-establishment-step-up-and-lifecycle-acceptance.md)

## Accepted Phase 3 Boundary

Phase 3 is accepted at:

```text
phase-3-authorization-control-complete-v1
```

Accepted evidence:

```text
33 manifest migrations
33 registered migrations
16 sequential test files
9 concurrency test files
408 PASS
0 FAIL
3 understood WARN
```

Phase 3 established deterministic Authorization Policy Version selection,
controlled policy binding, required-stage closure, supporting-record
enforcement, finalization-once Decision Records, controlled Authorization
Lease issuance, exact-context verification and use, fail-closed current
state revalidation, and independent-connection concurrency proofs.

See:

- [Authorization Decision and Lease Issuance Model](authorization-decision-and-lease-issuance-model.md)
- [Authorization Evaluation Contract](authorization-evaluation-contract.md)
- [Phase 3 Authorization Decision and Controlled Lease Acceptance](phase-3-authorization-decision-and-controlled-lease-acceptance.md)

The formal acceptance record was committed after the annotated tag. The tag
identifies the exact accepted SQL and test tree; later documentation commits
must not alter that accepted implementation without Phase 3 revalidation.


## Accepted Phase 4 Boundary

Phase 4 approval independence and separation of duties is formally accepted at:

```text
phase-4-approval-independence-and-separation-of-duties-complete-v1
```

Accepted result:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
16 concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
159 phase-gate PASS checks
0 phase-gate FAIL checks
```

The accepted scope includes controlled Approval Action recording, requester and
directly affected identity independence, effective-actor uniqueness,
organization and Authority Grant origin independence, reciprocal-request
protection, delegated-grant lineage, incompatible-authority and prohibited-duty
enforcement, current stage satisfaction, finalization-once Approval Requests,
Decision Record stage linkage, later-use approval continuity, and seven
independent-connection concurrency proofs.

The Platform Foundation remains domain-neutral. Location services,
communications, GIS rendering, operational workstations, user interfaces, and
module-specific workflows remain downstream architecture areas.

See:

- [Approval Independence and Separation of Duties](approval-independence-and-separation-of-duties-model.md)
- [Phase 4 Approval Independence and Separation of Duties Acceptance](phase-4-approval-independence-and-separation-of-duties-acceptance.md)
- [Resource Telemetry and Performance-Regression Testing](resource-telemetry-and-performance-regression-testing-model.md)
- [Foundation Migration Timeout and Execution Performance Standard](foundation-migration-timeout-and-execution-performance-standard.md)

## Documentation Groups

### Boundaries, Trust, Authentication, and Database Enforcement

- [Foundation Terminology and Domain Neutrality](foundation-terminology-and-domain-neutrality.md)
- [Platform Boundaries](platform-boundaries.md)
- [Authentication and Authorization Evaluation](authentication-and-authorization-evaluation-model.md)
- [Authentication Assertion Verification and Consumption Model](authentication-assertion-verification-and-consumption-model.md)
- [Phase 1 Authentication Assertion Acceptance](phase-1-authentication-assertion-acceptance.md)
- [Session Establishment, Step-Up, and Lifecycle Model](session-establishment-step-up-and-lifecycle-model.md)
- [Database Security](database-security-model.md)
- [Schema Naming Conventions](schema-naming-conventions.md)
- [SQL Migration Map](sql-migration-map.md)

### Organizations, Services, Identity, and Eligibility

- [Organization and Governed Scope](organization-and-governed-scope-model.md)
- [Service Participation and Federation](service-participation-and-federation-model.md)
- [Organizational Attestation and Access Eligibility](organizational-attestation-and-access-eligibility-model.md)

### Approval and Authorization

- [Approval Independence and Separation of Duties](approval-independence-and-separation-of-duties-model.md)
- [Authorization Evaluation Contract](authorization-evaluation-contract.md)
- [Authorization Decision and Lease Issuance Model](authorization-decision-and-lease-issuance-model.md)
- [Approval Framework](approval-framework.md)
- [Authority and Authorization](authority-and-authorization-model.md)
- [Authorization Lease](authorization-lease-model.md)
- [Decision Record Repository](decision-record-repository.md)

### Governance, Classification, and History

- [Data Classification and Information Governance](data-classification-and-information-governance-model.md)
- [Governed Document and Policy Versioning](governed-document-and-policy-versioning-model.md)
- [Lifecycle Versioning and Historical Lineage](lifecycle-versioning-and-historical-lineage-model.md)

### Compliance, Assurance, Findings, and Risk

- [Compliance and Control Framework](compliance-and-control-framework.md)
- [Common Security Control Catalog](common-security-control-catalog.md)
- [Compliance Profile Versioning](compliance-profile-versioning-model.md)
- [Control Implementation and Assurance Artifact Model](control-implementation-and-assurance-artifact-model.md)
- [Security Finding, Exception, and Remediation](security-finding-exception-and-remediation-model.md)
- [Risk Assessment and Treatment](risk-assessment-and-treatment-model.md)
- [Threat and Abuse Case](threat-and-abuse-case-model.md)

### Resilience, Performance, Experience, and Observability

- [Resilience, Availability, and Recovery](resilience-availability-and-recovery-model.md)
- [Performance, Efficiency, and Resource Governance](performance-efficiency-and-resource-governance-model.md)
- [Resource Telemetry and Performance-Regression Testing](resource-telemetry-and-performance-regression-testing-model.md)
- [Foundation Migration Timeout and Execution Performance Standard](foundation-migration-timeout-and-execution-performance-standard.md)
- [Client Experience and Accessibility](../../../modules/CAD/docs/architecture/user-interface/client-experience-and-accessibility-model.md)
- [Accessibility and Inclusive Interaction](../../../modules/CAD/docs/architecture/user-interface/accessibility-and-inclusive-interaction-model.md)
- [Observability, Health, and Operational Telemetry](observability-health-and-operational-telemetry-model.md)

## Current Implementation Boundaries

The `000–099` migrations establish the initial Foundation data model,
controlled APIs, security inventories, validation views, and the formally
accepted Phase 4 approval-independence and separation-of-duties behavior.

The accepted Phase 4 concurrency enforcement applies only to governed approval
state. It does not add CAD records, mapping state, workstation state,
presentation state, transport state, or module-owned workflows to the
Foundation.

The following remain incomplete until separately implemented and tested:

- Complete Decision Record cryptographic integrity and later
  review/supersession controls,
- Final production ownership and login-role topology,
- Least-privileged runtime grants and controlled write paths,
- Full append-only mutation protection,
- Migration-checksum population and enforcement,
- Production Go services,
- External-System Adapters and delivery workers,
- Off-host integrity anchoring and protected export,
- Backup protection and restoration validation,
- Break-glass procedures,
- Trusted rebuild and compromise recovery.

## Active Phase 5 Boundary

Phase 5 Step 1 freezes the production database role, ownership, migration,
runtime privilege, investigation, audit, validation, default-privilege, and
break-glass contract.

No production role SQL, ownership transfer, or runtime grant is introduced in
Step 1. The accepted Phase 4 SQL and executable test tree remain unchanged.

See:

- [Production Database Role, Ownership, and Runtime Privilege Model](production-database-role-ownership-and-runtime-privilege-model.md)

## Foundation Migration Execution Contract

Every ordinary migration listed by `sql/schema/manifests/foundation.manifest`
uses transaction-local limits of:

```sql
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';
```

Ordinary DDL should finish within a few seconds. An individual statement
observed above ten seconds requires investigation. The one-minute statement
limit is a hard execution-safety ceiling, not an expected duration and not a
general performance-regression budget.

The static contract validator is:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

The Phase 4 formal-acceptance gate invokes the validator before database execution.
It remains independently runnable for focused migration review.

See [Foundation Migration Timeout and Execution Performance Standard](foundation-migration-timeout-and-execution-performance-standard.md).

## Change Discipline

A Foundation change should normally update:

1. The governing architecture document,
2. The applicable SQL migration or a new migration,
3. The authoritative manifest when migration order changes,
4. The SQL migration map,
5. Positive and negative automated tests,
6. Concurrency tests when state can be consumed or changed simultaneously,
7. Operational or deployment documentation when the change crosses the
   database boundary.

## Phase 3 Step 3 Controlled Decision Finalization

Step 3 extends migration `081` with deterministic policy resolution,
controlled policy binding, complete policy-stage closure, policy-backed
`NOT_REQUIRED`, required supporting-evidence checks, finalization-once
behavior, and rejection of caller-supplied result mismatches.

The Step 3 regression target is 33 migrations, 14 sequential tests, 4
concurrency tests, 297 passes, zero failures, and the same three understood
warnings. Authorization Lease issuance remains Step 4.

## Accepted Phase 4 Approval Boundary

Phase 4 is formally accepted at `phase-4-approval-independence-and-separation-of-duties-complete-v1` with 34 manifest migrations,
21 sequential tests, 16 concurrency tests, 734 PASS, 0 FAIL, and the same
three understood WARN results.

The active revalidation gate is:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh
```

The annotated tag identifies the exact accepted SQL and executable test tree.
The formal acceptance record is an administrative documentation change that
must descend from the tag without changing the accepted implementation.

## Accepted Phase 5 Step 2 Implementation

Phase 5 Step 2 implements the separate deployment tree, deployment migration
registry, canonical PostgreSQL role shells, and bounded capability membership
topology.

It does not transfer object ownership or grant protected object privileges.

- [Phase 5 Step 2 — Deployment Manifest and PostgreSQL Role Topology](phase-5-step-2-deployment-role-topology.md)

## Active Phase 5 Step 3

Step 3 transfers the database and protected objects to approved `NOLOGIN`
owner roles, revokes existing `PUBLIC` database and protected-object access,
and establishes creator-specific default privileges.

Runtime service grants remain deferred to Phase 5 Step 4.

- [Phase 5 Step 3 — Ownership and Creator-Specific Default Privileges](phase-5-step-3-ownership-and-default-privileges.md)

## Active Phase 5 Step 4

Step 4 exposes only the approved controlled Foundation routines and bounded
delivery APIs through inherited capability roles. It grants no direct
protected-table or sequence privileges to runtime identities.

See:

- [Phase 5 Step 4 — Least-Privileged Runtime Grants and Controlled Service APIs](phase-5-step-4-least-privileged-runtime-grants.md)

<!-- ISSP_PHASE5_STEP5_REVIEW_AND_VALIDATION_ROLES -->

## Phase 5 Step 5 — Review and Validation Roles

Phase 5 Step 5 implements separate `NOLOGIN` investigator, audit-reader, and validation-reader capabilities through an exact 40-row view-only privilege contract. The implementation adds two reduced-disclosure investigator views, eight audit-lineage views, and 23 validation-posture views. No review role receives direct protected base-table, sequence, mutation, routine-execution, schema-creation, or temporary-object authority. Phase 5 Step 6 may implement disabled-at-rest break-glass activation and credential lifecycle controls.

## Phase 5 Step 6 Implementation Status

Phase 5 Step 6 implements disabled-at-rest `issp_break_glass` activation,
independent approval evidence, bounded expiration, forced deactivation,
append-only emergency evidence, off-host-export requirements, and external
credential lifecycle policy through deployment migration
`940_break_glass_and_credential_lifecycle.sql`. Credentials, private keys,
tokens, and passwords remain outside the repository and database. Phase 5 Step
7 may perform hostile-condition and role-race validation.

## Phase 5 Step 7 — Hostile-Condition and Role-Race Validation

Phase 5 Step 7 adds hostile-input and PostgreSQL role-race validation plus one pre-freeze hardening correction to deployment migration `940_break_glass_and_credential_lifecycle.sql`: an activated SCRAM verifier must use at least 4096 iterations and cryptographically match the independently approved fingerprint. It introduces no new deployment migration or authority. Concurrent preparation, activation, live-session deactivation, use-versus-closure, and expiration-versus-deactivation must remain deterministic, attributable, and fail-closed before Phase 5 formal acceptance.
