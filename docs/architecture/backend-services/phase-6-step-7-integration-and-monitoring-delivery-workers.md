# Phase 6 Step 7 — Integration and Monitoring Delivery Workers

> **Status:** Accepted implementation checkpoint.
>
> **Accepted implementation:** Commit
> `79e9723b2dd12e813de8a8c665d08d4f61cc8fab`, with 142 PASS and 0 FAIL in
> both static and complete validation.
>
> **Accepted predecessor:** Phase 6 Step 6 at commit
> `ec3c36081c686fa8ec82c8fd94bda421ed6cff42`, with 92 PASS and 0 FAIL in
> complete validation.
>
> **Boundary:** Step 7 implements only the two accepted durable delivery-worker
> identities and the six accepted Phase 5 claim, completion, and reschedule
> routines. It adds no migration, business listener, generic job framework,
> direct protected-table access, shared worker identity, or database transaction
> spanning an external network call.

## 1. Purpose

The accepted database boundary already contains durable integration outbox and
monitoring-delivery state plus controlled routines that atomically claim work,
complete a currently claimed item, or return it to a future retry state.

Step 7 supplies the bounded Go execution loops around those routines. The goal
is not to make arbitrary database rows executable work. The goal is to preserve
one explicit delivery path per service identity:

1. claim a bounded batch through the accepted security-definer routine;
2. finish the claim statement before performing network I/O;
3. send one bounded authenticated envelope to a deployment-owned relay;
4. use the durable item identifier as an idempotency key;
5. mark successful delivery or persist a stable redacted retry classification;
6. stop claiming on cancellation and drain in-flight work within the accepted
   process shutdown bound.

## 2. Exact Process and Database Authority

| Process | PostgreSQL identity | Controlled routines |
|---|---|---|
| `integration-delivery-worker` | `issp_service_integration_delivery` | `integration.claim_outbox_events(integer, interval)`, `integration.mark_outbox_event_delivered(uuid)`, `integration.reschedule_outbox_event(uuid, text, timestamptz)` |
| `monitoring-delivery-worker` | `issp_service_monitoring_delivery` | `observability.claim_monitoring_deliveries(integer, interval)`, `observability.mark_monitoring_delivery_delivered(uuid)`, `observability.reschedule_monitoring_delivery(uuid, text, timestamptz)` |

The Foundation API cannot construct either worker. The two worker identities
cannot invoke each other's routines. Neither worker receives direct relation or
sequence privileges on the protected delivery tables.

## 3. Operation-Specific Database Boundary

The underlying `pgxpool.Pool` remains private to `internal/database`. Step 7
adds only operation-specific methods:

```text
ClaimIntegrationOutbox
MarkIntegrationDelivered
RescheduleIntegration
ClaimMonitoringDeliveries
MarkMonitoringDelivered
RescheduleMonitoring
```

No caller-selected SQL string, query primitive, transaction primitive, batch,
copy operation, or raw pgx handle is exposed.

Claim methods call the accepted claim routines with a bounded batch size and
claim lease. Completion and reschedule methods accept one validated durable
identifier and fixed bounded arguments. Retry timestamps are constructed from
PostgreSQL `statement_timestamp()` plus a bounded duration so host clock skew
cannot produce a non-future retry time.

## 4. No Transaction Across External Delivery

Each claim routine executes as one PostgreSQL statement. Its statement
transaction is complete before the method returns the claimed records to the
worker package.

The worker package imports no pgx package, contains no SQL, and has no begin,
commit, or rollback primitive. External HTTP delivery therefore cannot occur
inside a PostgreSQL transaction.

Completion or reschedule is a separate bounded PostgreSQL statement after the
network result is known.

## 5. Deployment-Owned Relay Boundary

Workers do not interpret claimed database values as URLs, hosts, socket
addresses, credentials, or proxy instructions.

Each service receives one deployment-owned relay endpoint through:

```text
ISSP_DELIVERY_ENDPOINT
```

Remote endpoints require HTTPS. Plain HTTP is accepted only when
`ISSP_DELIVERY_ALLOW_INSECURE_LOCAL=true` and the endpoint uses a literal
loopback address. User information, fragments, query strings, raw paths, and a
root-only path are rejected.

The HTTP client explicitly disables ambient proxy configuration and redirects.
It applies bounded dial, TLS handshake, response-header, request, idle
connection, and body-drain behavior. TLS 1.2 or newer is required for remote
operation.

Database fields such as `external_system_name`, `destination_type`, and
`destination_reference` remain signed delivery metadata for the relay. They do
not select the network destination used by the worker.

## 6. Relay Credential Boundary

Each worker receives a distinct encrypted credential named:

```text
delivery-token
```

Planned encrypted sources are:

```text
/etc/iron-signal-platform/credentials/integration-delivery-worker.delivery-token.cred
/etc/iron-signal-platform/credentials/monitoring-delivery-worker.delivery-token.cred
```

The unit maps the credential through:

```text
ISSP_DELIVERY_TOKEN_FILE=%d/delivery-token
```

The credential file must satisfy the accepted protected-file boundary and
contain canonical unpadded base64url encoding for 32 through 64 bytes. The
decoded token is retained only by the relay client, explicitly zeroed after a
clean worker drain, and never included in configuration logs, worker logs,
database retry text, or validation output.

## 7. Delivery Envelope

Every request uses HTTP POST and the fixed envelope version:

```text
ISSP-DELIVERY-V1
```

The envelope contains:

```text
version
kind
 delivery_id
attempt_number
claim_expires_at
metadata
payload
```

`kind` is exactly `integration_outbox` or `monitoring_delivery`.

The worker adds:

```text
Authorization: Bearer <service-specific token>
Idempotency-Key: <durable delivery identifier>
X-ISSP-Delivery-Kind: <kind>
X-ISSP-Delivery-Attempt: <attempt number>
```

The total encoded envelope is limited to 256 KiB. Metadata is separately
limited to 32 KiB. Relay response bodies are neither trusted nor logged and are
drained only to a four-KiB limit.

## 8. Delivery and Idempotency Semantics

A 2xx response is delivery success. The worker then invokes the exact
completion routine.

A timeout, connection error, 408, 425, 429, or 5xx response is a transient
failure. Other non-2xx responses are classified as relay rejection. Both are
stored only as stable bounded codes; response content and endpoint details are
not stored.

The system provides at-least-once delivery, not exactly-once delivery. A network
failure can be ambiguous, and a process can stop after the relay accepts a
request but before PostgreSQL records completion. The relay must therefore
honor `Idempotency-Key` for the durable identifier.

A stale completion or reschedule result is treated as an understood no-op. The
worker does not overwrite newer durable state.

## 9. Claim and Concurrency Boundary

Configuration bounds are:

| Setting | Default | Accepted range |
|---|---:|---:|
| Batch size | 8 | 1–32 |
| Concurrent deliveries | 4 | 1–16 and no greater than batch size |
| Claim lease | 30 seconds | 10 seconds–5 minutes |
| Poll interval | 1 second | 100 milliseconds–30 seconds |
| Request timeout | 5 seconds | 1–30 seconds and less than claim lease |
| Initial retry delay | 5 seconds | 1 second–5 minutes |
| Maximum retry delay | 5 minutes | initial delay–24 hours |

One batch is fully processed before another batch is claimed. A semaphore
bounds concurrent external calls. No unbounded in-memory queue is created.

The accepted claim routines use row locks and `SKIP LOCKED`. Concurrent workers
therefore claim different currently eligible records rather than duplicating a
single active claim.

## 10. Retry Boundary

Retry delay uses deterministic exponential backoff capped by the configured
maximum. It uses the attempt number returned by PostgreSQL and does not use
unbounded arithmetic or random state.

Monitoring subscriptions already contain an accepted maximum retry count. The
monitoring reschedule routine returns `RETRY`, `FAILED`, or no current claim;
Step 7 preserves that result exactly.

The accepted integration outbox schema has no terminal failure routine or
per-contract maximum attempt count. Step 7 therefore makes the narrower claim:
it implements bounded per-attempt backoff and attributable retry state, but it
does not claim finite integration retry exhaustion or a dead-letter queue.
Adding terminal integration failure state requires a separately governed future
database change and is not smuggled into the Go worker.

## 11. Cancellation and Shutdown

On process cancellation:

- no new batch is claimed;
- in-flight HTTP requests receive cancellation;
- an item canceled during an ambiguous network operation is left under its
  existing claim lease rather than being immediately rescheduled;
- already successful relay calls receive one bounded completion attempt;
- already failed relay calls receive one bounded reschedule attempt;
- the process waits for the worker loop within `ISSP_SHUTDOWN_TIMEOUT`;
- the PostgreSQL pool remains open until worker drain finishes;
- readiness is cleared and `STOPPING=1` is emitted before drain;
- a clean drain closes idle relay connections and zeroes the retained token;
- shutdown timeout failure produces the software-failure exit class.

## 12. Logging and Error Boundary

Worker logs contain only bounded operation names, worker kind, and stable
classifications. They do not contain:

- delivery IDs;
- aggregate or destination identifiers;
- payloads or event filters;
- relay endpoint values;
- credentials or authorization headers;
- response bodies;
- PostgreSQL URLs or server error text.

The stable external-delivery classifications are:

```text
delivery_timeout
delivery_network_error
delivery_relay_unavailable
delivery_relay_rejected
delivery_payload_rejected
delivery_metadata_rejected
```

Database SQLSTATE and bounded database-stage diagnostics remain available
through the accepted database diagnostic boundary.

## 13. Implemented Candidate Source Boundary

```text
go/platform/
├── internal/
│   ├── config/
│   │   └── delivery_test.go
│   ├── database/
│   │   └── delivery.go
│   └── workers/
│       ├── delivery.go
│       ├── delivery_test.go
│       ├── delivery_integration_test.go
│       └── runner.go
├── scripts/
│   ├── test-delivery-workers.sh
│   └── test-delivery-workers-runtime.sh
└── testdata/
    └── phase6-step7/
        └── delivery-worker-fixtures.sql
```

The existing worker executable entrypoints remain direct and unchanged. Their
accepted bootstrap lifecycle now constructs and runs the exact worker matching
the compiled service identity.

## 14. Static Validation Evidence

Static validation must prove:

- the exact Step 6 predecessor revalidates in an isolated clone on branch
  `dev` with the canonical GitHub origin;
- accepted SQL, database tests, historical gates, Foundation adapter,
  authentication handoff, and business transport remain unchanged;
- all six protected worker routine references are confined to one
  operation-specific database file;
- the worker package contains no SQL, pgx import, or transaction primitive;
- claimed destination metadata cannot select the network endpoint;
- ambient proxies and redirects are disabled;
- envelope, metadata, batch, concurrency, lease, timeout, polling, retry, and
  shutdown bounds are explicit;
- idempotency headers and distinct service credentials are present;
- the two service identities and routine sets remain separate;
- Go formatting, vetting, tests, race tests, dependency verification, and
  systemd verification pass;
- documentation and validation indexes describe the same candidate.

## 15. Disposable Runtime Evidence

Complete validation uses PostgreSQL 18 and the unchanged accepted Foundation
and Phase 5 deployment migrations. It proves:

- exact integration and monitoring PostgreSQL identities connect;
- concurrent integration claims return distinct records;
- successful relay delivery persists `DELIVERED`;
- transient integration failure persists `RETRY` with a stable code;
- monitoring success persists `DELIVERED`;
- monitoring transient failure persists `RETRY`;
- monitoring retry exhaustion persists `FAILED`;
- the relay receives each test delivery once with the expected idempotency key
  and bearer credential;
- cross-worker routine calls are denied;
- workers have exact routine EXECUTE and no direct protected-table privilege;
- database and relay secrets do not appear in logs;
- temporary credentials and PostgreSQL state are removed;
- resource observations are recorded separately without enforcing premature
  performance thresholds.

## 16. Prohibited Work

Step 7 must not add:

- a Foundation or deployment migration;
- a second business API operation;
- a generic queue, scheduler, or job framework;
- a caller-selected SQL or network destination;
- direct protected-table access;
- a shared worker login or credential;
- a database transaction spanning an external call;
- unbounded batch, concurrency, payload, response, timeout, retry delay, queue,
  goroutine, or in-memory state;
- logging of protected payloads, identifiers, credentials, endpoints, or relay
  responses;
- exactly-once delivery, finite integration retry exhaustion, high
  availability, or production-readiness claims.

## 17. Acceptance Criteria

Phase 6 Step 7 is accepted only when:

- the Step 6 exact commit remains an ancestor of the candidate;
- the isolated Step 6 gate passes in the corresponding static or complete mode;
- all frozen predecessor paths remain unchanged;
- all candidate files exist and scripts are executable;
- both systemd worker units contain distinct database and relay credentials and
  bounded worker settings;
- the exact operation-specific source and service-identity boundaries pass;
- all unit, race, hostile, concurrency, privilege, persistence, cancellation,
  retry, redaction, and PostgreSQL 18 runtime evidence passes;
- static and complete Step 7 gates report zero failures;
- documentation and next-step sequencing are synchronized.

## 18. Explicit Non-Claims

Step 7 does not claim:

- arbitrary external systems can be contacted directly from database data;
- relay delivery is exactly once;
- integration outbox retries reach a terminal failed state;
- a dead-letter management interface exists;
- monitoring or integration delivery is highly available;
- production relay credentials or endpoints are provisioned;
- performance thresholds have been accepted;
- the platform is ready for production use.

## 19. Accepted Checkpoint

Step 7 was accepted and frozen at:

```text
Commit:              79e9723b2dd12e813de8a8c665d08d4f61cc8fab
Static validation:   142 PASS, 0 FAIL
Complete validation: 142 PASS, 0 FAIL
```

The accepted evidence includes exact worker identities, six operation-specific
database boundaries, distinct relay credentials, concurrency and retry bounds,
PostgreSQL 18 persistence, cross-role denial, redaction, and worker runtime
validation.

## 20. Next Step

Phase 6 Step 8 performs the consolidated hostile, failure, concurrency, and
resource validation campaign across the protected Foundation adapter,
authenticated transport, and both durable delivery workers.
