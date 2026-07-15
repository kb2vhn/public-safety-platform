# Phase 6 Step 5 — Controlled Foundation API Adapter

> **Status:** Accepted implementation checkpoint.
>
> **Accepted checkpoint:** Commit
> `1aefa613a80c1f5cdaf7807702b1b747d7e77ec5`; final complete validation
> reported 96 PASS and 0 FAIL.
>
> **Accepted predecessor:** Phase 6 Step 4 at commit
> `3e15c8cbb7b666537be6a7ec832800e8f4ca9af0`, with 71 PASS and 0 FAIL in
> complete validation.
>
> **Boundary:** Step 5 introduces exactly one typed protected-operation adapter
> over the accepted Phase 5 database API. It does not introduce a business
> listener, caller authentication, request-context construction, a generic data
> repository, direct table access, a migration, or a durable worker loop.

## 1. Purpose

Phase 6 Steps 1 through 4 established the production Go process topology,
reproducible build, typed configuration, service-specific PostgreSQL identity,
bounded database pools, local administrative health/readiness, systemd process
hosting, encrypted credential delivery, watchdog behavior, hostile runtime
validation, and graceful shutdown.

Step 5 proves the first narrow application-to-Foundation vertical slice. The
slice binds one existing authorization Decision Record to the uniquely
applicable accepted Authorization Policy Version by invoking the already
accepted controlled routine:

```text
decision.bind_authorization_policy(uuid)
```

The Go layer does not reimplement policy resolution. PostgreSQL remains the
single authority for row locking, policy selection, terminal deny persistence,
reason-code production, and statement atomicity.

## 2. Accepted Database Authority

The routine was accepted in the Phase 5 production database security boundary.
Its EXECUTE privilege is inherited only by the authorization service identity
through the bounded `issp_writer_authorization_decision` capability.

The exact production mapping is:

| Go process | PostgreSQL login | Capability | Controlled routine |
|---|---|---|---|
| `foundation-api` | `issp_service_authorization` | `issp_writer_authorization_decision` | `decision.bind_authorization_policy(uuid)` |

The integration-delivery and monitoring-delivery identities must not execute
this routine. The authorization service receives no direct relation privilege
on `decision.decision_records` or other protected Foundation tables.

## 3. Exact Operation Contract

The Step 5 adapter accepts exactly one value:

```text
DecisionID
```

`DecisionID` is a typed canonical non-zero UUID. Free-form SQL, policy
identifiers, result values, reason codes, organization context, target context,
and evaluation outcomes are not accepted from the caller.

The adapter returns:

```text
PolicyBindingResult {
    DecisionID
    ReasonCode
}
```

The returned Decision ID is the exact validated input reference. The returned
reason code is the exact stable value produced by PostgreSQL. The Go layer does
not replace, translate, broaden, or infer a different business result.

## 4. Stable Reason-Code Inventory

The adapter accepts only the following exact database results:

| Reason code | Meaning at the controlled routine boundary |
|---|---|
| `AUTHORIZATION_POLICY_SELECTED` | One uniquely applicable policy was selected and bound. |
| `AUTHORIZATION_POLICY_NOT_FOUND` | No applicable policy existed; PostgreSQL persisted a terminal DENY. |
| `AUTHORIZATION_POLICY_AMBIGUOUS` | Multiple equally authoritative policies remained; PostgreSQL persisted a terminal DENY. |
| `AUTHORIZATION_POLICY_CONTEXT_MISMATCH` | The expected policy reference did not match the resolved context; PostgreSQL persisted a terminal DENY. |
| `AUTHORIZATION_DECISION_ALREADY_FINALIZED` | The Decision Record was already terminal and was not changed. |
| `AUTHORIZATION_POLICY_ALREADY_BOUND` | The draft Decision Record already had a bound policy and was not rebound. |

Any unrecognized database value is a database-contract failure. It is not
returned as an open-ended string.

## 5. Decision Reference Validation

The production parser:

- trims surrounding whitespace;
- requires the canonical five-group UUID layout;
- accepts hexadecimal case and normalizes to lowercase;
- rejects malformed hexadecimal text;
- rejects missing separators;
- rejects the all-zero UUID;
- never includes the rejected input in its safe error text.

Validation occurs before database access.

## 6. Database Adapter Boundary

The underlying `pgxpool.Pool` remains private to `internal/database`.
Higher-level packages receive no raw connection, transaction, query-row,
execution, batch, or copy primitive.

Step 5 adds one operation-specific method to the database wrapper:

```text
BindAuthorizationPolicy(context, canonical Decision ID) -> reason code
```

The database package owns the only compile-time fixed statement:

```sql
SELECT decision.bind_authorization_policy($1::uuid)
```

The Foundation adapter can supply only one validated Decision ID. It cannot
supply SQL text, identifiers, argument lists, transactions, or a raw pgx
primitive. No string formatting, identifier interpolation, dynamic schema
selection, statement concatenation, or caller-supplied SQL is permitted.

## 7. Transaction and Concurrency Boundary

The accepted PostgreSQL function owns the complete mutation transaction for
this operation. The Go process does not open a wider application transaction
around the call.

The routine locks the Decision Record and performs policy resolution and any
resulting mutation inside one PostgreSQL statement. Concurrent calls for the
same draft record must serialize. For a uniquely applicable policy, exactly one
call returns `AUTHORIZATION_POLICY_SELECTED`; a racing call observes
`AUTHORIZATION_POLICY_ALREADY_BOUND`.

The Go layer performs no automatic retry. Callers receive the exact result or a
bounded typed error.

## 8. Timeout and Cancellation

Every adapter invocation receives a caller context and applies an additional
three-second operation deadline. A caller deadline that expires sooner remains
authoritative.

The timeout is intentionally not externally configurable in Step 5. This keeps
the first protected operation bounded and prevents deployment configuration
from silently expanding database execution time.

Cancellation and deadline errors retain Go error identity for
`errors.Is`. Safe diagnostics distinguish:

```text
foundation_context_canceled
foundation_deadline_exceeded
```

## 9. Identity Enforcement

The production constructor accepts only a database pool opened for the compiled
`foundation-api` identity:

```text
issp_service_authorization
```

Passing the integration-delivery or monitoring-delivery identity is rejected
before SQL executes. PostgreSQL independently enforces the same boundary
through schema and routine privileges.

The two layers are complementary:

1. Go prevents accidental cross-process adapter construction.
2. PostgreSQL prevents a compromised or incorrectly composed process from
   invoking authority it was not granted.

## 10. Error and Diagnostic Boundary

Adapter errors are typed and redacted. Their safe text contains only the
operation class and error class. It must not contain:

- the Decision ID;
- the database URL;
- a password or credential-file value;
- a PostgreSQL server message;
- a policy identifier;
- a protected target reference;
- a caller-supplied reason or result.

PostgreSQL SQLSTATE remains available as a bounded diagnostic, including
`postgres_sqlstate_P0002` for a nonexistent Decision Record and
`postgres_sqlstate_42501` for insufficient privilege.

## 11. Implemented Candidate Source Boundary

The candidate adds or changes only the following production and validation
areas:

```text
go/platform/
├── internal/
│   ├── database/
│   │   └── pool.go
│   └── foundation/
│       ├── authorization_policy.go
│       ├── authorization_policy_test.go
│       └── authorization_policy_integration_test.go
├── scripts/
│   ├── test-foundation-adapter.sh
│   └── test-foundation-adapter-runtime.sh
└── testdata/
    └── phase6-step5/
        └── authorization-policy-binding-fixtures.sql
```

The production binary entrypoints and process-host lifecycle remain unchanged.
The adapter is deliberately not exposed through HTTP, RPC, a command-line
operation, or a worker loop in this step.

## 12. Static Validation Evidence

Static validation must prove:

- the exact accepted Step 4 predecessor revalidates in an isolated clone on
  branch `dev` with the canonical GitHub origin;
- accepted Foundation SQL, deployment SQL, SQL tests, and historical gates are
  unchanged;
- the Step 4 process-host, service units, and hostile-runtime artifacts are
  unchanged;
- the production module and dependency graph remain exact;
- `pgx` imports remain confined to `internal/database`;
- the underlying pgx pool is not exported;
- exactly one protected routine reference exists in production Go source;
- the SQL statement is fixed and parameterized;
- no protected table name or mutating SQL verb appears in the adapter;
- the exact six reason codes are closed over by typed constants;
- the operation is limited to the Foundation API identity;
- the three-second timeout and context cancellation are tested;
- invalid UUIDs and unexpected reason codes fail closed;
- the administrative HTTP surface remains exactly `/healthz` and `/readyz`;
- no business transport, migration, or durable worker implementation exists;
- documentation and validation indexes describe the same candidate.

## 13. Disposable Runtime Evidence

Complete validation uses a disposable PostgreSQL 18 cluster and applies the
unchanged accepted Foundation and Phase 5 deployment migrations.

It proves:

- the authorization service connects under its exact compiled role;
- a uniquely applicable policy returns `AUTHORIZATION_POLICY_SELECTED`;
- no policy returns `AUTHORIZATION_POLICY_NOT_FOUND` and persists terminal
  DENY state on the same Decision Record;
- ambiguous policy selection returns `AUTHORIZATION_POLICY_AMBIGUOUS` and
  persists terminal DENY state;
- expected-policy mismatch returns
  `AUTHORIZATION_POLICY_CONTEXT_MISMATCH` and persists terminal DENY state;
- a nonexistent Decision ID returns a redacted typed SQLSTATE failure;
- two concurrent calls serialize to one selected and one already-bound result;
- the authorization role has exact routine EXECUTE and no direct protected
  table privilege;
- integration-delivery and monitoring-delivery roles lack routine EXECUTE;
- a direct wrong-role invocation fails;
- logs contain no password or PostgreSQL URL;
- all temporary credentials, processes, sockets, and PostgreSQL state are
  removed.

## 14. Prohibited Work

Step 5 must not add:

- a business-facing HTTP or RPC listener;
- authentication or trust-provider integration;
- caller-claim construction;
- transport request parsing;
- a generic repository or generic SQL executor;
- direct SELECT, INSERT, UPDATE, or DELETE authority over protected tables;
- a caller-selected policy identifier;
- a caller-selected final result or reason code;
- authorization-decision finalization;
- Authorization Lease issuance or consumption;
- approval evaluation;
- session mutation;
- integration or monitoring delivery behavior;
- automatic retries;
- a new Go dependency;
- a Foundation or deployment migration;
- a production-readiness claim.

## 15. Acceptance Criteria

Phase 6 Step 5 is accepted only when:

- the Step 4 exact commit remains an ancestor of the candidate;
- the isolated Step 4 gate passes in the corresponding static or complete mode;
- all frozen SQL and process-host paths remain unchanged;
- all candidate files exist and are executable where required;
- Go formatting, vetting, unit tests, race tests, module verification, tidy
  checks, and reproducible builds pass;
- static adapter validation reports zero failures;
- disposable PostgreSQL 18 adapter validation reports zero failures;
- exact positive, fail-closed, privilege-denial, concurrency, timeout,
  cancellation, and redaction evidence passes;
- no new dependency, business listener, migration, direct table access, or
  durable worker loop is present;
- all status and next-step documentation is synchronized.

## 16. Explicit Non-Claims

Step 5 does not claim:

- an external caller can reach the adapter;
- a request has been authenticated;
- a user identity or device assertion has been verified;
- authorization has been finalized;
- an Authorization Lease has been issued;
- the complete Foundation API exists;
- the process is horizontally scalable or highly available;
- production credentials have been provisioned;
- the platform is ready for production use.

## 17. Next Step

Phase 6 Step 6 now implements the Authenticated Request and Transport Boundary
as one loopback-only signed handoff and bounded route over this accepted
adapter, without allowing transport identity to become authorization.
