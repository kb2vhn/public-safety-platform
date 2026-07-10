# Public Safety Platform Trust and Decision Engine Model

## Purpose

This document defines how the Public Safety Platform establishes trust, evaluates requests, authorizes operational activity, records decisions, and enforces access across both the Go backend and PostgreSQL.

The platform does not assume that a request is trustworthy because a user supplied valid credentials.

Before the platform attempts to authenticate a user, it must first determine whether the requesting system is trusted enough to participate.

The platform follows this principle:

> Trust must be established before identity is evaluated, and identity must be established before operational authority can be exercised.

The Go backend and PostgreSQL form independent enforcement layers.

The Go backend evaluates the request and produces a signed attestation.

PostgreSQL independently verifies that attestation, validates database-owned facts, and enforces a short-lived authorization lease.

Neither layer blindly trusts the other.

---

# Core Security Philosophy

Traditional systems commonly follow a simplified model:

```text
User

  ↓

Authentication

  ↓

Role or Permission

  ↓

ALLOW / DENY
```

The Public Safety Platform uses a layered model:

```text
Requesting System

        ↓

Cryptographic Trust Establishment

        ↓

Device Trust Validation

        ↓

Identity Authentication

        ↓

Operational Authorization

        ↓

Operational Validation

        ↓

Approval Framework

        ↓

Decision Evaluation

        ↓

Authorization Lease

        ↓

Operational Action

        ↓

Decision Record and Justification Chain
```

No individual credential, role, device, approval, or authentication result is sufficient to establish operational authority.

Authority is established through independent, layered verification.

---

# Architectural Principles

## Trust Before Identity

The first question is not:

> Who are you?

The first question is:

> Is this system trusted enough to present an identity to the platform?

If the requesting system cannot establish cryptographic and device trust, the platform must stop processing before user authentication begins.

---

## Identity Is Not Authority

Authentication establishes who is making the request.

It does not establish that the person is:

* On duty
* Assigned to the requested function
* Qualified
* Approved
* Authorized for the requested operation
* Operating within an approved timeframe

Authentication proves identity.

Operational Authorization and Validation establish authority in context.

---

## The Backend Evaluates and Attests

The Go backend performs the first complete evaluation of the request.

It collects trust, identity, operational, approval, policy, and session context.

When those checks succeed, it produces a cryptographically signed Trust Assertion for PostgreSQL.

---

## PostgreSQL Verifies and Enforces

PostgreSQL does not blindly accept identity, device, session, authority, or approval information because the Go backend supplied it.

PostgreSQL independently verifies:

* The Trust Provider
* The assertion signature
* The device certificate
* The identity mapping
* The operational assignment
* The applicable authority grants
* Approval state
* Session state
* Time constraints
* Revocation state

PostgreSQL then issues or validates a short-lived Authorization Lease.

---

## Every Result Is Recorded

Every stage records its outcome.

This includes:

* PASS
* FAIL
* NOT_REQUIRED
* NOT_EVALUATED

Both successful and unsuccessful requests are meaningful parts of the platform system of record.

---

# High-Level Trust and Decision Flow

```text
Client or Requesting System

        │

        │ Presents certificate through mTLS

        ▼

Go Trust Evaluation

        │

        │ Validates certificate chain, revocation,
        │ device registration, and trust policy

        ▼

Identity Authentication

        │

        │ Resolves SID, UID, SPN, or other identity

        ▼

Operational Authorization and Validation

        │

        │ Assignment, shift, presence, authority,
        │ qualifications, scope, and expiration

        ▼

Approval Framework

        │

        │ Required independent approvals

        ▼

Go Decision Evaluation

        │

        │ Creates signed Trust Assertion

        ▼

PostgreSQL Trust Gate

        │

        │ Independently verifies assertion and
        │ authoritative database state

        ▼

Short-Lived Authorization Lease

        │

        │ Bound to identity, device, session,
        │ authority, scope, policy, and time

        ▼

Protected Database Operation

        │

        ├── Lease valid and requirements satisfied
        │         └── Operation evaluated
        │
        └── Lease expired, revoked, or invalid
                  └── DENY

        ▼

Decision Record Repository

        │

        ▼

Canonical Decision Record and Justification Chain
```

---

# Trust Foundation

## Purpose

The Trust Foundation determines whether a requesting system is permitted to participate in the platform.

It exists before user identity, operational authority, or module access is considered.

---

## Trust Foundation Evaluations

The Trust Foundation may evaluate:

* TLS connection security
* Client certificate presence
* Certificate signature algorithm
* Certificate validity period
* Certificate chain
* Root and intermediate CA trust
* Required certificate extensions
* Extended Key Usage
* Subject Alternative Name
* Certificate revocation
* Device registration
* Device status
* Trust Provider identity
* Environment or deployment boundary
* Platform trust policy version

---

# Enterprise PKI Integration

The Public Safety Platform is not a Certificate Authority.

It consumes the municipality's or agency's established PKI.

Supported trust sources may include:

* Microsoft Active Directory Certificate Services
* Enterprise intermediate certificate authorities
* Government or regional PKI infrastructure
* Other standards-compliant organizational certificate authorities

The platform records which certificate authorities and intermediate authorities are permitted to establish trust.

---

## Minimum Certificate Requirements

The platform requires certificate signatures using SHA-256 or stronger.

Certificate policies should remain configurable by the organization but may include:

* Minimum signature algorithm
* Minimum key strength
* Required Extended Key Usage
* Required certificate purpose
* Approved issuing CA
* Approved intermediate CA
* Maximum certificate lifetime
* Renewal window
* Revocation checking requirements

---

## Certificate Lifetime Targets

Short-lived certificates reduce the period during which a compromised key remains useful.

Suggested maximum lifetimes are:

| Device category                            | Suggested maximum certificate lifetime |
| ------------------------------------------ | -------------------------------------: |
| Static workstation                         |                                45 days |
| Mobile workstation, laptop, tablet, or MDT |                                31 days |
| Server or virtual machine                  |                                 7 days |

These values represent policy targets rather than hard-coded application behavior.

Organizations may adopt stricter requirements.

Certificate issuance and renewal should be automated to avoid unnecessary administrative or support workload.

---

# Certificate Revocation

The platform must support established PKI revocation mechanisms.

These may include:

* Certificate Revocation Lists
* Online Certificate Status Protocol
* Locally maintained emergency revocation state
* Approved CA or intermediate suspension
* Device-specific trust suspension

A certificate may remain within its validity dates and still be rejected because it has been revoked.

---

## Trust Failure Behavior

If cryptographic or device trust cannot be established:

```text
STOP

No user authentication

No operational authorization

No session establishment

No authorization lease

No operational module access
```

The failure must still produce a recorded trust decision.

---

# Device Trust

## Purpose

Device Trust establishes whether the physical or virtual system presenting the request is recognized and permitted to interact with the platform.

Device Trust is separate from identity authentication.

A trusted person using an untrusted device must not receive operational access.

---

## Device Trust Context

Device Trust may include:

* Device identifier
* Device category
* Device certificate thumbprint
* Certificate issuer
* Certificate serial number
* Registered hostname
* Registered organization
* Device owner or custodian
* Device status
* Enrollment state
* Trust policy
* Last successful trust validation
* Suspension or revocation state

---

## Device Trust States

Examples include:

```text
PENDING

TRUSTED

SUSPENDED

REVOKED

EXPIRED

RETIRED
```

A device in any state other than an explicitly accepted trust state must not establish an authorized session.

---

# Identity Authentication

## Purpose

Identity Authentication determines who is attempting to use the platform.

It occurs only after the requesting system has satisfied the minimum trust requirements.

---

## Identity Context

The platform may resolve and record:

* Platform identity identifier
* Person identifier
* Active Directory SID
* Unix UID
* Service Principal Name
* External identity provider identifier
* Authentication method
* Authentication factors
* Authentication timestamp
* Identity status
* Identity provider
* Identity assurance level

---

## Identity Rules

A valid identity must not automatically create:

* Operational authority
* Module access
* Supervisor status
* Administrative authority
* Resource assignment
* Approval authority

Identity is one component of the decision context.

---

# Operational Authorization

## Purpose

Operational Authorization determines whether the organization has granted an identity the authority to perform a defined operational function.

Operational Authorization answers:

> Has the organization authorized this identity to perform this function during this timeframe and within this scope?

---

## Operational Authorization Context

Operational Authorization may include:

* Position
* Assignment
* Organization
* Department
* Division
* Station
* Unit
* Shift
* Authority type
* Authority scope
* Effective time
* Expiration time
* Granting authority
* Approval policy
* Revocation state

Examples of operational positions include:

* Fire dispatcher
* EMS dispatcher
* Law enforcement dispatcher
* Shift supervisor
* Evidence custodian
* Records supervisor
* Incident commander

---

## Time-Bounded Authority

Operational authority should normally be time-bounded.

For scheduled duty:

```text
Scheduled Shift

        ↓

Supervisor Confirms Presence

        ↓

Operational Authority Becomes Eligible

        ↓

Session and Authorization Lease Established

        ↓

Shift Ends

        ↓

Controlled Closing Grace Period

        ↓

Authority Expires
```

If no authorized supervisor confirms that the person reported for duty, no operational authorization token or lease should be created.

---

## Closing Grace Period

A short closing period may permit personnel to complete existing work after the scheduled shift ends.

A typical target may be 10 to 15 minutes.

The platform should be able to restrict the operations available during this closing period.

Examples of permitted closing actions may include:

* Completing an existing report
* Closing an existing incident
* Transferring responsibility
* Finishing required documentation
* Logging out

The grace period should not automatically permit unrestricted creation of new operational work.

---

# Operational Validation

## Purpose

Operational Validation confirms that the conditions supporting an existing authorization remain true.

Operational Authorization establishes the grant.

Operational Validation confirms the current state.

---

## Operational Validation Questions

The platform may evaluate:

* Is the person still assigned?
* Is the person still marked present?
* Is the shift still active?
* Is the position still filled?
* Is the authority still within its approved timeframe?
* Has the supervisor withdrawn validation?
* Has the person left early?
* Has the assignment changed?
* Has the authority been revoked?
* Are required qualifications still valid?
* Is the device still trusted?
* Is the session still valid?

---

## Immediate Operational Changes

The platform must support immediate response to operational changes.

Examples:

```text
Supervisor marks person as LEFT_EARLY

        ↓

Operational Validation becomes invalid

        ↓

Authorization Lease is revoked or rejected

        ↓

Next protected operation is denied
```

Operational authority must not remain valid merely because a previously created token has not reached its original expiration time.

---

# Authority Grants

## Purpose

Authority Grants provide a generic, data-driven representation of operational authority.

The platform should not create separate authorization code for every event type.

Authority should be represented as:

```text
Who

What

Scope

Reason

Valid From

Valid Until

Approved By

Approval Requirements

Revocation State
```

---

## Emergency and Extended Operations

Operational extensions should not permanently modify a person's normal authority.

They should be represented as separate, temporary Authority Grants.

Example:

```text
Authority:

Dispatch Supervisor


Scope:

County Emergency Operations


Reason:

Major Incident Holdover


Valid From:

2026-07-10 19:00


Valid Until:

2026-07-10 23:00
```

The authorization engine does not need special code for:

* Fire extensions
* Tornado extensions
* Flood extensions
* Parade extensions
* Snow emergency extensions

The authority describes what may be done.

The reason records why the authority exists.

---

# Approval Framework

## Purpose

The Approval Framework provides reusable support for operations requiring one or more independent approvals.

The platform does not hard-code a literal two-person concept.

Instead, the Two-Person Concept becomes one policy supported by a broader Approval Framework.

---

## Supported Approval Models

The framework may support:

* Single approval
* Supervisor approval
* Independent approval
* Dual authorization
* Multi-party authorization
* Multi-stage approval
* Command approval
* Judicial approval
* External agency approval
* Emergency approval
* Time-limited approval

---

## Approval Framework Context

An approval requirement may define:

* Requested operation
* Required number of approvals
* Required approver authority
* Required approver organization
* Required order of approvals
* Whether approvals must be independent
* Whether self-approval is prohibited
* Effective time
* Expiration time
* Revocation rules
* Escalation behavior

---

## Self-Approval Prevention

The framework must prevent the requester from satisfying an independent approval requirement for their own request unless an explicit policy permits it.

Default behavior:

```text
Requester Identity

        ≠

Independent Approver Identity
```

---

## Approval Withdrawal

An approval may be withdrawn before the protected operation occurs.

When an approval is withdrawn:

* The approval requirement becomes unsatisfied.
* Any dependent authorization lease must be invalidated or rejected.
* The withdrawal must produce a new Decision Record.
* Previously recorded approvals must not be deleted or overwritten.

---

# Decision Engine

## Purpose

The Decision Engine evaluates whether a requested operation should proceed based on trusted and current context.

The Decision Engine answers:

> Is this trusted identity, using this trusted device, within this operational context, allowed to perform this action according to current policy?

---

## Decision Engine Responsibilities

The Decision Engine:

* Receives decision requests
* Collects decision context
* Evaluates trust results
* Evaluates identity state
* Evaluates operational authority
* Evaluates operational validation
* Evaluates approvals
* Evaluates policies
* Evaluates session state
* Evaluates requested scope
* Produces a final decision
* Produces a Justification Chain
* Creates a Decision Record

---

## Decision Engine Non-Responsibilities

The Decision Engine does not own:

* Personnel records
* CAD incidents
* RMS reports
* Evidence items
* Vehicle records
* Fleet maintenance records
* Qualifications
* Organizational schedules

It consumes authoritative facts from the domains that own them.

---

# Go Decision Evaluation

The primary evaluation engine is implemented in the Go backend.

The Go backend is responsible for:

* Receiving client requests
* Establishing mTLS
* Validating the certificate chain
* Performing revocation checks
* Resolving the registered device
* Authenticating the identity
* Collecting operational context
* Collecting approval context
* Evaluating applicable policies
* Requesting database authorization
* Managing authorization lease renewal
* Returning an application decision
* Recording complete evaluation results

The Go backend must not be able to bypass database verification by merely supplying user or device identifiers.

---

# Trust Providers

## Purpose

A Trust Provider is an approved backend service permitted to submit signed Trust Assertions to PostgreSQL.

Trust Provider registration prevents an arbitrary service from creating platform identity or authorization context.

---

## Trust Provider Record

A Trust Provider may include:

```text
Provider ID

Provider Name

Service Identity

Database Role

Signing Public Key

Provider Certificate Thumbprint

Allowed Assertion Types

Allowed Environment

Activated At

Expires At

Revoked At

Provider Status

Provider Software Version
```

---

## Trust Provider Requirements

A Trust Provider must:

* Use an approved database role.
* Present an approved service identity.
* Sign assertions using an approved signing key.
* Create assertions for the intended environment.
* Use bounded assertion lifetimes.
* Include unique assertion identifiers.
* Record its software version.
* Be independently revocable.

---

# Trust Assertions

## Purpose

A Trust Assertion is a cryptographically signed statement produced by an approved Go Trust Provider after completing its initial evaluation.

The assertion does not itself grant permanent authority.

It provides PostgreSQL with verifiable context from the backend.

---

## Trust Assertion Contents

A Trust Assertion should include:

* Assertion identifier
* Trust Provider identifier
* Issuer
* Audience
* Environment
* Issued timestamp
* Expiration timestamp
* Unique nonce
* Identity identifier
* Device identifier
* Device certificate thumbprint
* Certificate issuer
* Session identifier
* Operational assignment identifier
* Authority grant identifiers
* Approval context
* Requested operation
* Requested scope
* Trust policy identifier and version
* Authorization policy identifier and version
* Backend engine version
* Correlation identifier

---

## Assertion Signature

The Trust Assertion must be signed by the approved Trust Provider.

PostgreSQL must verify:

* The signing provider is active.
* The signing key is approved.
* The signature is valid.
* The assertion has not expired.
* The assertion is intended for the current environment.
* The assertion has not been replayed.
* The connection originates from an approved database role.

---

# PostgreSQL Trust Gate

## Purpose

The PostgreSQL Trust Gate independently verifies the Trust Assertion and all database-owned facts required to authorize database access.

The database must not be blind to invalid or inconsistent claims from the application layer.

---

## PostgreSQL Verification Requirements

Before creating an authorized context, PostgreSQL verifies:

* Trust Provider is registered and active.
* Trust Provider database role is permitted.
* Assertion signature is valid.
* Assertion audience matches the platform.
* Assertion environment matches the deployment.
* Assertion remains within its validity period.
* Assertion identifier has not been replayed.
* Certificate authority remains approved.
* Intermediate certificate authority remains approved.
* Device certificate thumbprint is registered.
* Device certificate record remains active.
* Device remains trusted.
* Device has not been suspended or revoked.
* Identity remains active.
* Identity mapping matches the supplied identifiers.
* Device-to-identity relationship is permitted.
* Operational assignment remains active.
* Required supervisor validation remains active.
* Authority Grants remain valid.
* Approval requirements remain satisfied.
* Requested operation is permitted within the approved scope.
* No applicable revocation state exists.

---

# Dual-Layer Trust Attestation and Enforcement

The Public Safety Platform uses independent application and database validation layers.

The Go backend performs the initial trust evaluation. It validates the presented certificate chain, revocation status, device registration, identity authentication, and available operational context.

After completing these checks, the backend creates a cryptographically signed Trust Assertion.

PostgreSQL does not blindly accept the context supplied by the backend.

Before establishing an authorized database context, PostgreSQL verifies:

* The assertion was issued by an approved Trust Provider.
* The assertion signature is valid.
* The assertion is intended for the current platform environment.
* The assertion has not expired or been replayed.
* The referenced certificate authority remains trusted.
* The device certificate fingerprint is registered and active.
* The certificate belongs to the referenced device.
* The identity mapping remains active.
* Required operational assignments and validations remain valid.
* Required approvals and authority grants remain satisfied.

After successful verification, PostgreSQL creates a short-lived Authorization Lease.

The platform follows this principle:

> The backend evaluates and attests. The database verifies and enforces. Neither layer is permitted to treat the other layer's unverified claims as authoritative.

---

# Authorization Lease

## Purpose

An Authorization Lease is a short-lived database authorization object created after PostgreSQL successfully verifies a Trust Assertion.

The lease permits protected operations only within a defined context, scope, and timeframe.

---

## Authorization Lease Binding

The lease should be bound to:

* Trust Provider
* Identity
* Person
* Device
* Device certificate
* Session
* Organization
* Operational assignment
* Authority Grants
* Approval state
* Requested scope
* Allowed operations
* Trust policy version
* Authorization policy version
* Go engine version
* Database verification version
* Issue time
* Expiration time
* Revocation state
* Decision identifier

---

## Authorization Lease Lifetime

The database lease should be significantly shorter than the certificate or operational assignment lifetime.

Separate controls apply to:

| Security object           |                            Example lifetime |
| ------------------------- | ------------------------------------------: |
| Device certificate        |                           7, 31, or 45 days |
| Operational Authorization | Approved shift plus controlled grace period |
| Authorization Lease       |                    Short renewable interval |

The exact lease interval should be established by platform policy and risk level.

A sensitive operation may require a shorter lease than a low-risk operation.

---

## Database Time Is Authoritative

The Go backend may track expiration for application behavior, renewal, and user notification.

PostgreSQL remains authoritative for lease expiration.

Conceptually:

```sql
clock_timestamp() < authorization_lease.expires_at
```

When the lease expires, PostgreSQL must deny the next protected operation even when:

* The Go process believes the lease remains valid.
* A frontend retains a cached token.
* A coding error skips an application expiration check.
* A request is delayed in transit.
* A previous session remains open.

Go cannot extend a lease by modifying local state.

It must request renewal from PostgreSQL.

---

## Maximum Lease Expiration

An Authorization Lease must never extend beyond the earliest applicable boundary.

Examples include:

* Device certificate expiration
* Trust Assertion expiration
* Session expiration
* Operational assignment expiration
* Authority Grant expiration
* Approval expiration
* Shift expiration plus approved grace period
* Trust Provider expiration

Conceptually:

```text
Lease Expiration = Earliest Applicable Expiration Boundary
```

---

# Authorization Lease Renewal

The Go backend may request renewal before the lease expires.

Renewal is not automatic acceptance.

PostgreSQL must reevaluate current authoritative state.

A renewal request may be denied because:

* The certificate was revoked.
* The device was suspended.
* The identity was disabled.
* The assignment ended.
* The person was marked off duty.
* An approval was withdrawn.
* The Authority Grant expired.
* Policy changed.
* The Trust Provider was revoked.
* The session was terminated.

Each renewal attempt must produce a recorded decision.

---

# Protected Database Operations

Protected operations must not rely only on raw session variables such as:

```sql
SET app.identity_id = '...';
SET app.device_id = '...';
SET app.authorized = 'true';
```

Those values alone are claims and may be forgeable.

Protected functions should require a verified Authorization Lease or database-established trusted context.

Conceptually:

```sql
SELECT authorization.establish_context(
    signed_trust_assertion
);
```

The database verifies the assertion and returns:

```text
Authorization Lease ID

Expiration Time

Authorized Scope

Allowed Operations

Decision ID
```

A protected operation then supplies the lease:

```sql
SELECT evidence.transfer_item(
    authorization_lease_id,
    evidence_item_id,
    destination_location_id
);
```

The protected function rechecks the lease using PostgreSQL time and current revocation state.

---

# Database Enforcement Depth

Different operations may require different validation depth.

## Standard Protected Operation

A standard operation may validate:

* Lease exists
* Lease is active
* Lease has not expired
* Lease has not been revoked
* Operation is within lease scope

---

## High-Risk Protected Operation

A high-risk operation may additionally revalidate:

* Current device state
* Current identity state
* Current operational assignment
* Current approval state
* Current Authority Grant
* Current policy version

Examples of high-risk operations include:

* Evidence disposition
* Sealing or unsealing records
* Emergency authority creation
* Identity lifecycle changes
* Provider registration
* Security policy changes
* Administrative privilege changes

---

# Revocation

## Purpose

Revocation permits the platform to terminate trust or authority before natural expiration.

---

## Revocation Sources

A lease may become invalid because of:

* Device certificate revocation
* CA or intermediate CA revocation
* Device suspension
* Identity suspension
* Identity disablement
* Session termination
* Assignment termination
* Supervisor removal of on-duty status
* Authority Grant revocation
* Approval withdrawal
* Policy revocation
* Trust Provider revocation

---

## Revocation Flow

```text
Authoritative State Changes

        ↓

Related Authorization Lease Becomes Invalid

        ↓

Next Protected Database Operation

        ↓

PostgreSQL Revalidates Lease

        ↓

DENY

        ↓

Decision Record Created
```

For critical changes, the platform may proactively mark dependent leases as revoked.

---

# Replay Protection

The platform must prevent reuse of Trust Assertions and other one-time authorization artifacts.

Replay protections may include:

* Unique assertion identifier
* Unique nonce
* Short assertion lifetime
* Audience restriction
* Environment restriction
* Provider restriction
* Session binding
* Device certificate binding
* Used-assertion registry
* Correlation tracking

PostgreSQL must reject an assertion that has already been consumed when the assertion type is defined as single-use.

---

# Decision Requests

## Purpose

A Decision Request represents an attempted operation requiring evaluation.

A Decision Request may include:

* Requested operation
* Requesting identity
* Device
* Session
* Target module
* Target resource
* Requested scope
* Correlation identifier
* Request timestamp
* Parent operation
* Workflow context

---

# Evaluation Results

Every evaluation stage must produce a result.

Allowed evaluation states include:

```text
PASS

FAIL

NOT_REQUIRED

NOT_EVALUATED
```

`NOT_EVALUATED` must not be treated as success.

A required stage that was not evaluated must cause the final decision to fail safely.

---

# Final Decision Results

Final decisions may include:

```text
ALLOW

DENY

PENDING

ESCALATED
```

## ALLOW

All required checks passed and the operation may proceed.

## DENY

One or more required conditions failed.

## PENDING

The operation requires additional context, approval, or processing.

## ESCALATED

The request has been routed for additional authorization or organizational review.

---

# Justification Chain

## Purpose

The Justification Chain explains why the platform reached a decision.

It is not an evidence chain and must not be confused with law enforcement evidence or chain of custody.

The Justification Chain is part of the Decision Record.

---

## Justification Chain Example

```text
Decision ID:

9f8e...


Timestamp:

2026-07-10T09:42:18.482Z


Operation:

Approve Evidence Transfer


Decision:

ALLOW


Justification:


✓ Certificate Chain Valid

  Certificate Thumbprint:

  SHA256:...


✓ Device Trusted

  Device Certificate Thumbprint:

  SHA256:...


✓ Identity Authenticated

  SID:

  S-1-5-...

  UID:

  ...

  SPN:

  ...


✓ Operational Authorization Active

  Position:

  Fire Dispatch Supervisor

  Valid From:

  07:00

  Valid Until:

  19:00


✓ Operational Validation Passed

  Supervisor:

  Identity ...

  Validation:

  Marked Present for Duty


✓ Approval Framework Satisfied

  Approval Policy:

  Independent Supervisor Approval

  Required Approvals:

  1

  Completed Approvals:

  1


✓ Authority Grant Valid


✓ Session Valid


✓ Authorization Lease Valid


✓ Requested Operation Authorized


Authorization Engine Version:

2.4.1


Policy Version:

8.3


Trust Policy Version:

5.2


Decision Evaluation Time:

4.7 ms
```

---

# Negative Justification

Denied requests must include the successful stages as well as the failed stage.

Example:

```text
Decision:

DENY


Justification:


✓ Certificate Chain Valid

✓ Device Trusted

✓ Identity Authenticated

✓ Operational Authorization Located

✗ Operational Validation Failed


Reason:

No authorized supervisor confirmed presence for duty.


Result:

Session creation and database authorization denied.
```

This provides complete context rather than recording only the final failure.

---

# Engine and Policy Versioning

Every decision must record the versions of the engines and policies that contributed to it.

Examples include:

* Go Trust Engine version
* Go Authorization Engine version
* PostgreSQL Trust Gate version
* PostgreSQL authorization function version
* Trust policy version
* Device policy version
* Operational Authorization policy version
* Approval policy version
* Module policy version
* Workflow version

Versioning allows future investigators and administrators to understand which rules existed when the decision was made.

---

# Decision Record Repository

## Purpose

The Decision Record Repository is the authoritative store for platform decisions.

It contains canonical platform records rather than destination-specific log formats.

The repository is part of the platform system of record.

---

## Decision Record Contents

A Decision Record may contain:

* Decision ID
* Parent decision ID
* Correlation ID
* Request timestamp
* Decision timestamp
* Requested operation
* Target module
* Target resource
* Final result
* Identity context
* Device context
* Certificate context
* Session context
* Organization context
* Operational assignment context
* Authority Grant context
* Approval context
* Policy identifiers
* Policy versions
* Engine versions
* Evaluation stages
* Justification Chain
* Evaluation time
* Lease identifier
* Lease expiration
* Revocation references
* Canonical metadata

---

## Immutable Record Principle

Decision Records should be append-only.

Existing records should not be rewritten to alter history.

If a correction, revocation, or later determination is required, the platform creates a new linked record.

Examples:

```text
Original Decision

        ↓

Revocation Decision

        ↓

Corrective Decision

        ↓

Administrative Review
```

The relationship between the records preserves the complete history.

---

# Recording Pass and Fail Results

Every stage must be recorded whether it passes or fails.

A failed request may reveal:

* User error
* Expired assignment
* Policy conflict
* Misconfiguration
* Certificate problem
* Revoked device
* Compromised account
* Unauthorized activity
* Operational staffing problem
* Approval failure

Repeated failures may trigger a configured notification or workflow.

---

# Failure Pattern Response

The Public Safety Platform is not a SIEM or dedicated security product.

However, repeated or significant platform failures may require an operational response.

Examples include:

* Repeated certificate failures
* Repeated device trust failures
* Repeated denied operations
* Repeated failed approval attempts
* Repeated invalid lease use
* Repeated requests after shift expiration
* Repeated attempts from a revoked provider

Configured platform policy may initiate:

* Notification
* Supervisor review
* IT support review
* Security review
* Workflow task
* Temporary suspension
* Operational incident record

The authoritative failure records remain in the Decision Record Repository.

---

# Canonical Record Model

Decision Records must use the platform's canonical schema.

They must not be designed around:

* Graylog GELF
* Splunk field conventions
* Elastic index mappings
* Security Onion event formats
* Vendor-specific schemas

External systems receive translated representations.

They do not define the platform's internal model.

---

# Platform Provider Streaming Service

## Purpose

The Platform Provider Streaming Service distributes canonical platform records to approved external systems.

It is part of the Go backend architecture.

---

## Streaming Targets

Potential providers include:

* Graylog
* Security Onion
* Elastic Stack
* Splunk
* Syslog
* OpenTelemetry
* Webhooks
* Custom municipal systems
* Future providers

---

## Streaming Flow

```text
Decision Record Repository

        ↓

Platform Provider Streaming Service

        ↓

Provider Adapter

        ↓

Destination-Specific Representation

        ↓

External System
```

---

## Streaming Boundary

External systems may:

* Store copies
* Search records
* Correlate events
* Create dashboards
* Generate alerts
* Support monitoring
* Support investigations

External systems do not replace the Public Safety Platform as the authoritative system of record.

---

# Database Conceptual Model

The database implementation may include concepts such as:

```text
trust_providers

trusted_certificate_authorities

registered_devices

device_certificates

trust_assertions

consumed_assertions

identities

identity_mappings

operational_assignments

operational_validations

authority_grants

approval_policies

approval_requests

approval_actions

decision_requests

decision_evaluations

decision_records

decision_justifications

authorization_leases

authorization_lease_revocations
```

The final table and schema design must follow the data ownership, platform boundary, and naming convention documents.

---

# Fail-Safe Behavior

The platform must fail safely.

Examples:

* Missing required context results in DENY.
* Unknown Trust Provider results in DENY.
* Invalid assertion signature results in DENY.
* Expired assertion results in DENY.
* Unknown certificate results in DENY.
* Unknown device results in DENY.
* Expired lease results in DENY.
* Required evaluation not performed results in DENY.
* Database verification failure results in DENY.
* Policy ambiguity results in DENY or PENDING according to explicit policy.

The platform must not convert system uncertainty into unrestricted access.

---

# Availability and Emergency Operations

Fail-safe behavior must be balanced with public safety availability requirements.

Emergency access must not bypass accountability.

Emergency policies may permit controlled degraded operation when explicitly designed and approved.

Any degraded or emergency authorization must include:

* Explicit emergency policy
* Defined scope
* Defined reason
* Defined approving authority
* Defined expiration
* Enhanced Decision Recording
* Post-event review requirement

Emergency access must create temporary authority, not permanent privilege.

---

# Complete Trust Chain

```text
Enterprise PKI

        ↓

Certificate Chain Validation

        ↓

Device Trust

        ↓

Identity Authentication

        ↓

Operational Authorization

        ↓

Operational Validation

        ↓

Approval Framework

        ↓

Go Decision Evaluation

        ↓

Signed Trust Assertion

        ↓

PostgreSQL Trust Gate

        ↓

Authorization Lease

        ↓

Protected Database Operation

        ↓

Decision Record Repository

        ↓

Platform Provider Streaming Service

        ↓

Approved External Consumers
```

---

# Architectural Invariants

The following statements must remain true as the platform evolves:

1. An untrusted system must not reach user authentication.

2. Authentication alone must not establish operational authority.

3. No application identity may increase its own authority.

4. No person may satisfy an independent approval requirement for their own request unless explicitly authorized by policy.

5. Operational Authority must be scoped and time-bounded.

6. PostgreSQL must independently verify application trust claims before permitting protected operations.

7. Go must not be able to extend a database Authorization Lease through local state alone.

8. PostgreSQL time is authoritative for database lease expiration.

9. Every required evaluation must produce a recorded result.

10. Every final decision must produce a Decision Record and Justification Chain.

11. Failed and denied requests must be preserved.

12. External systems must not replace the platform as the authoritative system of record.

13. Emergency authority must be explicit, temporary, scoped, and auditable.

14. Revocation must take effect before natural expiration when an underlying trust condition becomes invalid.

15. A required evaluation that was not performed must never be interpreted as a pass.

---

# Final Principle

The Public Safety Platform must never ask only:

> Does this user have permission?

It must ask:

> Is this trusted identity, using this trusted device, operating within a valid assignment and approved context, allowed to perform this action according to current policy?

Trust establishes the boundary.

Operational Authorization establishes organizational authority.

Operational Validation confirms that the required conditions remain true.

The Approval Framework enforces independent organizational approval.

The Go backend evaluates and attests.

PostgreSQL independently verifies and enforces.

The Decision Record Repository preserves the complete reasoning.

Together, these layers create an operational platform whose decisions are explainable, attributable, observable, revocable, and dependable when they matter most.

