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

## Current Accepted Boundaries

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

Step 4 is validated at:

```text
33 manifest migrations
33 registered migrations
15 sequential test files
4 concurrency test files
329 PASS
0 FAIL
3 understood WARN
```

Step 5 expands fail-closed lease behavior for stale session, identity, device,
Trust Provider, Platform Service, policy, supporting evidence, authority, and
protected-operation attribution. Its target is 16 sequential tests and 353
passes while preserving the same 33 migrations and 4 accepted concurrency
tests.

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

Run the current phase gate from the repository root:

```bash
./tools/validation/phase-gates/validate_phase3_step5.sh
```

Run the complete Foundation SQL suite directly:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

The framework creates a disposable PostgreSQL database, applies the
authoritative manifest, runs sequential and concurrency tests, writes logs and
summaries, and removes a successful test database.

## Documentation

Start with:

- [Platform Documentation](docs/README.md)
- [Architecture Index](docs/architecture/README.md)
- [Platform Foundation Documentation](docs/architecture/foundation/README.md)
- [Authorization Decision and Lease Issuance Model](docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md)
- [Validation Tools](tools/validation/README.md)

## Production Readiness

The repository is pre-alpha. Production use still requires deployment-role
separation, least-privileged grants, host compromise containment, secret and
key management, integrity anchoring, off-host logging, protected backups,
restore testing, break-glass controls, incident response, and trusted rebuild
and compromise recovery.

## License

BSD 3-Clause.
