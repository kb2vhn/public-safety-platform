# Phase 6 Step 6 — Authenticated Request and Transport Boundary

> **Status:** Implementation candidate. Acceptance is not yet claimed.
>
> **Accepted predecessor:** Phase 6 Step 5 at commit
> `1aefa613a80c1f5cdaf7807702b1b747d7e77ec5`, with 96 PASS and 0 FAIL in
> final complete validation.
>
> **Boundary:** Step 6 exposes only the accepted Step 5 authorization-policy
> binding operation through one loopback business listener. It establishes a
> signed authentication handoff, typed request context, replay protection,
> request limits, stable envelopes, cancellation, and shutdown behavior. It
> does not convert transport identity into authorization, add a second
> protected operation, or introduce a migration, session store, generic router,
> direct table access, or worker loop.

## 1. Purpose

Steps 1 through 5 established the production Go processes, exact database
identities, reproducible build, process-host boundary, and one controlled
Foundation adapter over:

```text
decision.bind_authorization_policy(uuid)
```

Step 6 creates the first business transport around that adapter. The transport
is deliberately local and narrow. A separately governed authentication gateway
terminates the external authentication mechanism and forwards a signed,
short-lived authentication result to the Foundation API over a literal
loopback address.

The signed handoff proves that the configured gateway supplied the
authentication context. It does not prove that the authenticated subject is
permitted to bind a policy, and none of its identity fields are passed to SQL.
PostgreSQL remains authoritative for the Step 5 protected operation.

## 2. Exact Listener and Route

Only `foundation-api` receives the business listener.

```text
Listener: literal loopback TCP address
Method:   POST
Path:     /v1/foundation/authorization-policy-bindings
Media:    application/json
```

The integration-delivery and monitoring-delivery workers continue to expose
only their loopback administrative health/readiness listener. They reject all
Step 6 business-listener and handoff-key configuration.

The administrative listener remains separate and continues to expose exactly:

```text
/healthz
/readyz
```

No business route is registered on the administrative listener.

## 3. Trusted Authentication Handoff

The trusted local gateway supplies these exact signed headers:

```text
X-Iron-Signal-Request-ID
X-Iron-Signal-Correlation-ID
X-Iron-Signal-Subject
X-Iron-Signal-Provider
X-Iron-Signal-Assertion-ID
X-Iron-Signal-Authenticated-At
X-Iron-Signal-Nonce
X-Iron-Signal-Signature
```

The request and correlation identifiers are canonical non-zero UUIDs. Subject,
provider, and assertion identifiers are bounded opaque identifiers. They are
not interpreted as roles, organizations, purposes, scopes, permissions, or
resource authority.

The authenticated-at value is canonical UTC RFC3339Nano. The handoff is valid
only within a 30-second age window and five seconds of permitted future clock
skew.

The nonce is canonical unpadded base64url for 16 through 32 bytes.

## 4. Signature Contract

The gateway and Foundation API share one service-specific HMAC key delivered as
an encrypted systemd credential named:

```text
transport-hmac-key
```

The credential file contains canonical unpadded base64url encoding of 32
through 64 random bytes.

The signature uses HMAC-SHA-256 over this exact newline-delimited input:

```text
ISSP-HANDOFF-V1
POST
/v1/foundation/authorization-policy-bindings
<request-id>
<correlation-id>
<subject>
<provider>
<assertion-id>
<authenticated-at>
<nonce>
<lowercase SHA-256 request-body digest>
```

The signature header is:

```text
v1=<64 lowercase hexadecimal characters>
```

Comparison uses constant-time HMAC equality. Missing, repeated, malformed,
stale, future, or invalid signed fields return one indistinguishable
`AUTHENTICATION_REQUIRED` response.

## 5. Replay Boundary

A valid signature is not sufficient for repeated use.

The Foundation API records a SHA-256 replay key derived from the request ID,
nonce, and signature in a mutex-protected in-memory window. Verification and
replay insertion are atomic, so concurrent duplicates produce exactly one
winner.

The replay window:

- contains at most 1,024 entries;
- removes only expired entries;
- does not silently evict an unexpired entry;
- fails closed with `SERVICE_BUSY` if valid authenticated traffic fills the
  bounded window;
- is process-local and resets on controlled restart.

This replay protection applies to the gateway handoff, not to the protected
Foundation operation's business idempotency. PostgreSQL continues to serialize
and classify repeated policy-binding calls.

## 6. Typed Context Separation

After verification, the transport owns a typed authentication context:

```text
Request ID
Correlation ID
Authenticated subject
Authentication provider
External assertion identifier
Authenticated-at time
Server-received time
```

Only the request and correlation identifiers are returned in the response.
The subject, provider, and assertion identifier are not logged and are not
passed into the Step 5 adapter.

The JSON body contains exactly:

```json
{"decision_id":"<canonical non-zero UUID>"}
```

The Decision ID is a caller-supplied operation reference. It is validated by
the typed Step 5 parser and is the only value passed to the controlled adapter.

The transport accepts no caller-selected role, organization, purpose, scope,
policy identifier, result, reason code, permission, or SQL value.

## 7. Request Limits

The business listener enforces:

- one exact route;
- POST only;
- no query string;
- `application/json`, optionally with UTF-8 charset only;
- maximum request body of 1,024 bytes;
- maximum header bytes of 8 KiB;
- two-second header timeout;
- five-second read and write timeouts;
- thirty-second idle timeout;
- four-second total handler context;
- configurable concurrency from 1 through 32, default 8;
- non-queueing overload rejection;
- strict JSON with unknown fields and trailing content rejected.

The Step 5 adapter retains its independent three-second operation deadline.
The earlier caller or transport deadline remains authoritative.

## 8. Trusted Proxy Decision

Step 6 does not trust proxy-derived identity or addressing headers.

Requests containing any of the following are rejected:

```text
Forwarded
X-Forwarded-For
X-Forwarded-Host
X-Forwarded-Proto
X-Real-IP
```

The listener is loopback-only, and the signed handoff is the sole accepted
transport authentication result. A future deployment that needs network proxy
attribution requires a separate governed contract.

## 9. Stable Response Envelopes

A successful call returns HTTP 200 with:

```json
{
  "request_id": "...",
  "correlation_id": "...",
  "result": {
    "decision_id": "...",
    "reason_code": "..."
  }
}
```

The reason code is the exact closed Step 5 value returned by PostgreSQL.

Errors use:

```json
{
  "request_id": "...",
  "correlation_id": "...",
  "error": {
    "code": "...",
    "message": "request rejected"
  }
}
```

Pre-authentication failures do not echo request or correlation identifiers.
Database errors, SQLSTATE, SQL text, credentials, subject identity, provider,
assertion identifier, and internal error text are never returned.

## 10. Error Mapping

The exact transport codes include:

| HTTP | Code | Boundary |
|---|---|---|
| 400 | `INVALID_REQUEST` | Proxy spoofing, malformed JSON, invalid Decision ID |
| 401 | `AUTHENTICATION_REQUIRED` | Missing, malformed, stale, invalid, or replayed handoff |
| 404 | `NOT_FOUND` | Unknown path or query-bearing path |
| 405 | `METHOD_NOT_ALLOWED` | Method other than POST |
| 413 | `REQUEST_TOO_LARGE` | Body exceeds 1,024 bytes |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | Media type outside the accepted boundary |
| 500 | `FOUNDATION_OPERATION_FAILED` | Redacted protected-operation failure |
| 503 | `SERVICE_BUSY` | Concurrency or replay capacity exhausted |
| 503 | `OPERATION_CANCELED` | Upstream cancellation |
| 504 | `OPERATION_TIMEOUT` | Bounded operation deadline exceeded |

The transport does not translate PostgreSQL reason codes into HTTP denial or
approval. A completed protected operation remains HTTP 200 with its exact
reason code.

## 11. Configuration and Credential Boundary

Foundation API requires:

```text
ISSP_BUSINESS_LISTEN_ADDRESS
ISSP_TRANSPORT_HMAC_KEY_FILE
ISSP_TRANSPORT_MAX_CONCURRENT_REQUESTS
```

The systemd unit supplies:

```text
LoadCredentialEncrypted=transport-hmac-key:/etc/iron-signal-platform/credentials/foundation-api.transport-hmac-key.cred
ISSP_TRANSPORT_HMAC_KEY_FILE=%d/transport-hmac-key
```

The handoff key is separate from the PostgreSQL credential. It is read from a
protected regular file, decoded, copied into the verifier, and removed from the
bootstrap buffer. It never enters `Config`, logs, health output, or build
artifacts.

The worker units receive no business listener or transport credential.

## 12. Startup, Readiness, and Shutdown

Foundation API readiness requires successful completion of:

1. typed configuration;
2. protected handoff-key loading;
3. process-host environment validation;
4. administrative listener bind;
5. PostgreSQL connectivity and exact-role compatibility;
6. Step 5 adapter construction;
7. business handler construction;
8. business listener bind;
9. readiness transition and service-manager notification.

On shutdown, readiness clears first. The watchdog stops, `STOPPING=1` is sent,
business requests drain within the accepted shutdown timeout, the
administrative listener stops, and the PostgreSQL pool closes.

A business listener bind failure exits 71. An unexpected post-readiness
business listener failure exits 70.

## 13. Implemented Candidate Boundary

```text
go/platform/
├── internal/
│   ├── authentication/
│   │   ├── handoff.go
│   │   └── handoff_test.go
│   ├── bootstrap/
│   ├── config/
│   └── transport/
│       ├── business.go
│       └── business_test.go
└── scripts/
    ├── test-authenticated-transport.sh
    └── test-authenticated-transport-runtime.sh
```

The production module graph is unchanged. HMAC, SHA-256, base64url, JSON,
HTTP, replay locking, and timeout behavior use the Go standard library.

## 14. Static Evidence

Static validation must prove:

- the exact Step 5 commit revalidates in an isolated `dev` clone;
- accepted SQL, Step 5 adapter, module, toolchain, and database operation
  boundary remain unchanged;
- only Foundation API accepts business transport configuration;
- only Foundation API receives the transport credential;
- one exact route exists;
- transport and authentication packages contain no SQL;
- HMAC-SHA-256, constant-time equality, freshness, canonicalization, and atomic
  replay behavior are present;
- body, header, timeout, concurrency, JSON, proxy, and response limits are
  tested;
- no new dependency, migration, protected routine, direct table access,
  session store, router framework, or worker loop is introduced;
- Go formatting, vetting, unit tests, race tests, module verification, and
  process-host unit verification pass;
- documentation and validation indexes are synchronized.

## 15. Disposable Runtime Evidence

Complete validation creates a disposable PostgreSQL 18 cluster, applies the
unchanged accepted Foundation and Phase 5 deployment migrations, starts the
real `foundation-api` binary, and proves:

- readiness requires the business listener;
- a correctly signed request invokes the exact Step 5 adapter and persists the
  expected policy binding;
- the response preserves request ID, correlation ID, Decision ID, and reason
  code;
- exact replay is rejected;
- an invalid signature is rejected;
- a stale handoff is rejected;
- strict JSON rejects unknown fields;
- proxy-spoofing headers are rejected;
- method, media type, and body-size limits are enforced;
- SIGTERM drains and exits zero;
- logs disclose no database credential, HMAC key, subject, or assertion
  identifier;
- all temporary credentials, processes, ports, and PostgreSQL state are
  removed.

## 16. Prohibited Work

Step 6 must not add:

- a second protected Foundation operation;
- database authentication-assertion consumption;
- local role, organization, purpose, scope, or permission evaluation;
- a caller-selected policy or result;
- direct protected-table access;
- a migration;
- a generic SQL executor;
- a general router framework;
- trusted proxy attribution;
- an externally reachable non-loopback listener;
- a session store, cookie, bearer-token parser, or refresh-token flow;
- a durable worker loop;
- automatic retries;
- a new Go dependency;
- a production-readiness claim.

## 17. Acceptance Criteria

Step 6 is accepted only when:

- the Step 5 exact commit remains an ancestor;
- the isolated Step 5 static and complete gates pass;
- the business listener and transport credential are Foundation-API-only;
- all authentication, replay, request, response, timeout, concurrency,
  cancellation, shutdown, and redaction evidence passes;
- the Step 5 adapter and exact database statement remain unchanged;
- no scope prohibited by Section 16 appears;
- static and complete Step 6 gates report zero failures;
- all current-status and next-step documentation is synchronized.

## 18. Explicit Non-Claims

Step 6 does not claim:

- the gateway itself is implemented or accepted;
- an external user can reach the loopback listener directly;
- authenticated identity has been authorized;
- an Authentication Assertion was consumed by PostgreSQL;
- a session was established;
- an authorization decision was finalized;
- an Authorization Lease was issued;
- the complete Foundation API exists;
- the platform is production ready.

## 19. Next Step

After Step 6 is accepted, Phase 6 Step 7 may implement the integration and
monitoring delivery workers through their already accepted PostgreSQL claim,
completion, and retry routines. Step 7 must preserve the process, credential,
database-role, transport, and bounded resource boundaries accepted through
Step 6.
