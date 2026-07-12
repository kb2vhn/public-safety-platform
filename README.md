
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

The Foundation currently covers trust, identity, sessions, authorization,
approvals, Decision Records, governance, compliance, resilience, performance,
observability, integration intent, and resource governance.

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

## Active Foundation Phase

### Phase 4 — Approval Independence and Separation of Duties

Step 1 freezes the normative contract before production SQL changes.

The contract defines:

- Approval Action Record terminology
- Effective actor uniqueness
- Requester and directly affected identity independence
- Self-approval prevention
- Duplicate approval prevention
- Explicit reciprocal approval-cycle checks
- Typed Authority Grant binding
- Incompatible-authority enforcement modes
- Separation-of-duties duties and prohibited combinations
- Current stage satisfaction
- Finalization-once Approval Requests
- Withdrawal, correction, and supersession through new action records
- Independent-connection concurrency requirements

Governing contract:

- [Approval Independence and Separation of Duties Model](docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md)

Step 1 changes no SQL, migration manifest, or SQL test file. The accepted Phase
3 suite remains the regression boundary.

## Core Principles

- Authentication is not authorization.
- Trust is additive; no single credential or role grants unrestricted access.
- Required decision stages fail closed.
- PostgreSQL is an independent security boundary.
- No ordinary account is a god account.
- Material decisions and lifecycle changes must be attributable.
- Historical state must not be silently rewritten.
- Approval Action Records are distinct from supporting records, assurance
  artifacts, and module-owned evidence records.
- External providers must remain replaceable.
- Performance and resource bounds are design requirements.

## Repository Layout

```text
.
├── docs/
│   ├── architecture/
│   ├── compliance-profiles/
│   └── goals/
├── go/
│   └── experiments/
├── sql/
│   └── schema/
│       ├── manifests/
│       ├── migrations/
│       └── scripts/
├── test-framework/
│   └── sql/
└── tools/
    └── validation/
        └── phase-gates/
```

Phase validators are intentionally kept out of the repository root.

## Validation

Validate Phase 4 Step 1:

```bash
./tools/validation/phase-gates/validate_phase4_step1.sh
```

Validate the formal Phase 3 acceptance checkpoint:

```bash
./tools/validation/phase-gates/validate_phase3_step7.sh
```

Run the complete Foundation SQL suite directly:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

## Documentation

Start with:

- [Platform Documentation](docs/README.md)
- [Architecture Index](docs/architecture/README.md)
- [Platform Foundation Documentation](docs/architecture/foundation/README.md)
- [Phase 4 Approval Independence and Separation of Duties](docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Phase 3 Acceptance](docs/architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- [Validation Tools](tools/validation/README.md)

## Production Readiness

The repository is pre-alpha. Production use still requires deployment-role
separation, least-privileged grants, host compromise containment, secret and
key management, integrity anchoring, off-host logging, protected backups,
restore testing, break-glass controls, incident response, and trusted rebuild
and compromise recovery.

## License

BSD 3-Clause.
