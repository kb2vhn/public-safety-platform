# Phase 6 Step 8 — Hostile, Failure, Concurrency, and Resource Validation

> **Status:** Implementation candidate. Acceptance is not yet claimed.
>
> **Accepted predecessor:** Phase 6 Step 7 at commit
> `79e9723b2dd12e813de8a8c665d08d4f61cc8fab`, with 142 PASS and 0 FAIL in
> both static and complete validation.
>
> **Boundary:** Step 8 adds validation code, hostile fixtures, orchestration,
> resource observation, and synchronized documentation only. It adds no
> production operation, route, migration, dependency, service identity,
> database privilege, relay authority, or worker behavior.

## 1. Purpose

Phase 6 Steps 3 through 7 established the first production Go vertical slice:

- bounded process bootstrap and PostgreSQL 18 connectivity;
- hardened Linux process-host integration;
- one controlled Foundation policy-binding adapter;
- one authenticated and bounded business route; and
- two service-specific durable delivery workers.

Step 8 does not extend those capabilities. It attempts to break them.

The campaign proves that malformed, replayed, expired, forged, oversized,
concurrent, canceled, delayed, disconnected, cross-role, and resource-pressure
conditions remain bounded, redacted, attributable, and fail-closed.

## 2. Frozen Production Boundary

The accepted Step 7 commit is the production-source predecessor:

```text
79e9723b2dd12e813de8a8c665d08d4f61cc8fab
```

Step 8 freezes these paths byte-for-byte against that commit:

```text
go/platform/go.mod
go/platform/go.sum
go/platform/TOOLCHAIN
go/platform/cmd/
go/platform/internal/authentication/handoff.go
go/platform/internal/bootstrap/
go/platform/internal/config/
go/platform/internal/database/
go/platform/internal/foundation/authorization_policy.go
go/platform/internal/observability/
go/platform/internal/processhost/
go/platform/internal/transport/business.go
go/platform/internal/transport/health.go
go/platform/internal/workers/delivery.go
go/platform/internal/workers/runner.go
go/platform/deployment/
sql/schema/
sql/deployment/
test-framework/sql/
```

Only `_test.go` files, test fixtures, test scripts, phase-gate logic, and
synchronized documentation may change in Step 8.

## 3. Correctness and Resource Outcomes Remain Separate

Every complete Step 8 run reports three independent states:

```text
Correctness result: PASS or FAIL
Resource observation: RECORDED or NOT_RECORDED
Performance thresholds: NOT_EVALUATED
```

A correctness failure cannot be hidden by a resource report. A resource value
cannot fail correctness because Phase 6 has no governed performance budget yet.
A missing or malformed report is validation-infrastructure failure when the
complete Step 8 gate requires telemetry.

## 4. Authentication Handoff Hostile Matrix

The authentication campaign covers:

- HMAC key lengths below and above the accepted range;
- signature key mismatch;
- uppercase, truncated, extended, or wrong-version signatures;
- method and route tampering;
- request and correlation identifier tampering;
- subject, provider, and assertion tampering;
- authentication-time tampering, expiration, and future skew;
- nonce tampering and noncanonical encoding;
- request-body digest tampering;
- concurrent replay attempts with exactly one winner;
- replay-store capacity at exactly 1,024 entries;
- capacity rejection without unbounded growth; and
- deterministic removal of expired replay entries.

Authentication context remains evidence of authentication only. No Step 8 test
may add a role, policy, permission, organization, purpose, or authorization
result to the signed request body.

## 5. Business Transport Hostile Matrix

The business-transport campaign covers:

- wrong routes, raw queries, and unsupported methods;
- unsupported or malformed media types;
- strict JSON rejection of unknown and trailing content;
- oversized request bodies;
- oversized request headers at the actual listener;
- duplicate authentication headers;
- body and signed-identity tampering;
- every prohibited proxy-authority header;
- replay rejection without disclosing replay state;
- non-queueing concurrency saturation;
- parent cancellation and deadline propagation;
- adapter timeout, cancellation, and internal failure mapping;
- bounded response envelopes and safety headers;
- request and correlation preservation only after authentication; and
- redaction of PostgreSQL, caller, gateway, and internal error detail.

Route and media rejection occur before handoff consumption. A request rejected
before authentication therefore cannot poison the bounded replay store.

## 6. Controlled Foundation Adapter Hostile Matrix

The adapter campaign covers:

- malformed and zero Decision Record identifiers;
- wrong process identity at construction;
- nil context and unavailable adapter state;
- the exact closed reason-code inventory;
- unknown database reason-code rejection;
- nonexistent Decision Record redaction;
- concurrent binding serialization;
- caller cancellation;
- the fixed adapter timeout; and
- a PostgreSQL row-lock wait terminated by the caller's earlier deadline.

The lock test proves that a blocked protected routine does not bypass request
cancellation or disclose the locked Decision Record.

## 7. Delivery Worker Hostile Matrix

Both worker identities are exercised against the same deployment-owned relay
surface with distinct credentials. The campaign covers:

- successful delivery;
- request timeout;
- immediate connection loss;
- 408, 425, 429, and 5xx transient classification;
- permanent non-2xx rejection classification;
- prohibited redirect handling;
- malformed HTTP response handling;
- bounded draining of large response bodies;
- ambient HTTP and HTTPS proxy variables;
- database destination metadata containing URL-like attacker text;
- durable idempotency keys;
- distinct bearer credentials per worker;
- bounded batch concurrency;
- payload and metadata rejection before network delivery;
- completion and reschedule failures;
- cancellation that leaves ambiguous claims for lease recovery;
- clean credential zeroing after drain; and
- logs and durable retry codes that contain no identifiers, payloads,
  credentials, endpoints, or relay response bodies.

Database-selected destination fields remain relay metadata. They never become a
URL, proxy, redirect target, socket address, or credential selector.

## 8. PostgreSQL Failure and Concurrency Matrix

The disposable PostgreSQL 18 campaign proves:

- exact service-role connection identity;
- Foundation API denial from worker routines;
- integration-worker denial from monitoring routines;
- monitoring-worker denial from the Foundation adapter routine;
- no direct protected-table read or mutation authority;
- concurrent claim separation through `SKIP LOCKED`;
- expired claim lease recovery with an incremented attempt count;
- concurrent completion with exactly one successful state transition;
- stale completion as a bounded false/no-op result;
- transient retry persistence;
- monitoring retry exhaustion persistence;
- no external network operation inside a PostgreSQL transaction;
- no deadlock in the hostile campaign; and
- database state survives client timeout, disconnect, and completion races.

The campaign uses only accepted migrations and accepted controlled routines.
It creates no Step 8 migration or runtime grant.

## 9. Repetition and Race Detection

The static adversarial runner performs:

- three consecutive package-test campaigns;
- two complete race-detector campaigns; and
- two additional Step 8-focused hostile repetitions.

The complete gate also revalidates the exact Step 7 predecessor in an isolated
clone whose checked-out branch is named `dev`. Historical gates are not
weakened to accept later artifacts.

## 10. Resource Observation

The complete hostile-runtime campaign writes:

```text
phase6-step8-resources.txt
phase6-step8-resources.json
```

The JSON schema identifier is:

```text
ISSP-PHASE6-STEP8-RESOURCE-V1
```

The report records:

- host name, operating system, kernel, logical CPU count, CPU model, installed
  memory, and available temporary-filesystem space;
- exact Go toolchain and PostgreSQL version;
- total elapsed time and measured campaign elapsed text;
- user and system CPU, effective CPU percentage, maximum resident set,
  page faults, filesystem operation counters, and context switches;
- database size, WAL generation, transactions, shared block reads and hits,
  temporary files and bytes, tuple counters, and deadlocks; and
- the hostile subcampaign outcomes.

The resource observation is a baseline input only. It is not an assurance claim
or a production capacity promise.

## 11. Security and Redaction

Step 8 reports must not contain:

- PostgreSQL passwords or URLs;
- relay bearer credentials or authorization headers;
- HMAC keys or signatures;
- Decision Record, delivery, aggregate, destination, or subscription identifiers
  outside fixed synthetic test identifiers;
- protected payloads or event filters;
- relay response bodies;
- server exception text; or
- unrestricted PostgreSQL logs.

All temporary credentials, PostgreSQL state, sockets, and hostile servers are
removed after the run. Explicit resource reports remain only in the selected
results directory.

## 12. Artifacts

Step 8 adds:

```text
go/platform/internal/authentication/handoff_step8_hostile_test.go
go/platform/internal/foundation/authorization_policy_step8_integration_test.go
go/platform/internal/transport/business_step8_hostile_test.go
go/platform/internal/workers/delivery_step8_hostile_test.go
go/platform/internal/workers/delivery_step8_integration_test.go
go/platform/testdata/phase6-step8/hostile-delivery-fixtures.sql
go/platform/scripts/test-phase6-adversarial.sh
go/platform/scripts/test-phase6-adversarial-runtime.sh
tools/validation/phase-gates/validate_phase6_step8.sh
```

No production Go file is added or modified.

## 13. Prohibited Work

Step 8 must not add or change:

- a business operation or route;
- a Foundation or deployment migration;
- a Go module dependency;
- a service account, role, grant, or database ownership rule;
- authentication canonicalization or credential format;
- authorization logic;
- relay destination authority;
- claim, completion, retry, or shutdown semantics;
- process-host or systemd authority;
- a generic load generator, queue framework, or benchmark dependency;
- a performance threshold; or
- a production-readiness claim.

A product defect discovered by Step 8 requires a separately reviewed correction
and complete revalidation. The validation layer must not silently rewrite
production behavior to make the gate pass.

## 14. Acceptance Criteria

Phase 6 Step 8 is accepted only when:

- commit `79e9723b2dd12e813de8a8c665d08d4f61cc8fab` remains an ancestor;
- the exact Step 7 gate revalidates in an isolated `dev` clone;
- every frozen production path remains unchanged;
- all Step 8 test, fixture, script, gate, and documentation artifacts exist;
- scripts are executable and shell syntax is valid;
- no Step 8 production source, migration, dependency, deployment unit, or grant
  is added or modified;
- all Go package, repeated, and race campaigns pass;
- all hostile adapter, authentication, transport, relay, role, lease, and
  completion-race assertions pass;
- the PostgreSQL 18 campaign persists the exact expected stable outcomes;
- correctness is `PASS`;
- resource observation is `RECORDED`;
- performance thresholds remain `NOT_EVALUATED`;
- the resource JSON is complete, positive where required, nonnegative for
  counters, and reports zero deadlocks;
- runtime logs contain no credential or connection secret;
- static and complete Step 8 gates report zero failures; and
- all documentation and next-step sequencing are synchronized.

## 15. Explicit Non-Claims

Step 8 does not claim:

- production traffic volume has been modeled;
- a performance budget exists;
- high availability or multi-host failover has been proven;
- external identity providers or production relays are integrated;
- exactly-once delivery exists;
- integration retries have terminal exhaustion;
- all future Foundation operations are implemented; or
- the platform is production ready.

## 16. Next Step

After Step 8 is accepted, Phase 6 Step 9 creates the formal Phase 6 acceptance
record, performs the final frozen-boundary revalidation, and creates the
annotated Phase 6 implementation acceptance tag.
