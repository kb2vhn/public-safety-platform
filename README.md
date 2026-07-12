# Iron Signal Platform

> An Iron Signal Systems project
>
> **Built on purpose. Backed by discipline. Engineered to endure.**
>
> **Development status:** Pre-alpha, domain-neutral Platform Foundation
>
> This repository is not ready for production use.

Canonical repository:

```text
https://github.com/Iron-Signal-Systems/public-safety-platform
```

## Mission

Every important decision should have an explanation.

Build software that is secure, understandable, observable, and dependable
enough that local communities and institutions can rely on it when operations
matter most.

## Scope

Public safety is the first demanding module family, not the limit of the
Platform Foundation. The Foundation is domain-neutral and is intended to serve
public-safety, municipal, school, and other institutional modules without
embedding one module's business records into the shared security layer.

## Accepted Foundation Boundaries

### Phase 1 — Authentication Assertions

```text
31 manifest migrations
31 registered migrations
10 sequential test files
1 concurrency test file
135 PASS
0 FAIL
3 understood WARN
```

Tag: `phase-1-authentication-assertion-complete-v1`

### Phase 2 — Session Control

```text
32 manifest migrations
32 registered migrations
12 sequential test files
4 concurrency test files
213 PASS
0 FAIL
3 understood WARN
```

Tag: `phase-2-session-control-complete-v1`

### Phase 3 — Authorization Decision and Controlled Lease Issuance

```text
33 manifest migrations
33 registered migrations
16 sequential test files
9 concurrency test files
408 PASS
0 FAIL
3 understood WARN
```

Tag: `phase-3-authorization-control-complete-v1`

Acceptance record:

- [Phase 3 Authorization Decision and Controlled Lease Acceptance](docs/architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)

## Current Phase 4 Work

Phase 4 Step 1 froze the approval-independence and separation-of-duties
contract.

Phase 4 Step 2 added the typed structural extension in migration `083`,
structural test `170`, and observation-only resource telemetry.

Phase 4 Step 3 extends migration `083` with the controlled Approval Action
recording boundary and adds behavioral test `180`. The controlled function
binds one exact Approval Request, policy stage, effective actor, organization,
session, and Authority Grant at one authoritative time. Withdrawal,
correction, and supersession create new Approval Action Records linked to the
exact prior record. UPDATE and DELETE are rejected by append-only mutation
guards.

Step 3 does not yet claim self-approval prevention, directly affected identity
exclusion, duplicate effective-actor enforcement, reciprocal-cycle detection,
incompatible-authority enforcement, prohibited-duty enforcement, stage
satisfaction, or Approval Request finalization. Those remain Phase 4 Steps 4
through 6.

Step 3 target:

```text
34 manifest migrations
34 registered migrations
18 sequential test files
9 concurrency test files
500 PASS
0 FAIL
3 understood WARN

Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

## Core Principles

- Authentication is not authorization.
- Trust is additive; no single credential or role grants unrestricted access.
- Required decision stages fail closed.
- PostgreSQL is an independent security boundary.
- No ordinary account is a god account.
- Material decisions and lifecycle changes must be attributable.
- Historical state must not be silently rewritten.
- External providers must remain replaceable.
- Performance and resource bounds are design requirements.
- Correctness and resource observations are separate test outcomes.

## Validation

Run the active Phase 4 Step 3 gate:

```bash
./tools/validation/phase-gates/validate_phase4_step3.sh
```

Run the normal correctness suite:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

Run correctness plus resource observation:

```bash
./test-framework/sql/schema/scripts/test_foundation_with_resources.sh
```

## Documentation

Start with:

- [Platform Documentation](docs/README.md)
- [Architecture Index](docs/architecture/README.md)
- [Platform Foundation Documentation](docs/architecture/foundation/README.md)
- [Approval Independence and Separation of Duties](docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Resource Telemetry and Performance-Regression Testing](docs/architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md)
- [Validation Tools](tools/validation/README.md)

## Production Readiness

The repository is pre-alpha. Production use still requires deployment-role
separation, least-privileged grants, host compromise containment, secret and key
management, integrity anchoring, off-host logging, protected backups, restore
testing, break-glass controls, incident response, and trusted rebuild and
compromise recovery.

## License

BSD 3-Clause.
