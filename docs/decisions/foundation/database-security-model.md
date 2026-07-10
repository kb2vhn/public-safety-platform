# Platform Database Security Model

## Purpose

This document defines PostgreSQL as an independent enforcement boundary.

PostgreSQL is not a passive data store.

## Infrastructure Superuser Boundary

PostgreSQL necessarily has cluster-level superuser capability.

That capability must be treated as infrastructure-level emergency authority, not normal platform authority.

Controls should include:

- Separate named administrator identities
- No shared operational credential
- Strong authentication
- Restricted network path
- Mandatory reason for use
- Break-glass procedure
- Monitoring
- Independent review
- No use by the Go backend
- No routine application access

## No Non-Infrastructure God Access

Except for the infrastructure-superuser boundary, no human, service account, application identity, or database role may possess unrestricted authority across:

- Schema ownership
- Identity administration
- Device trust administration
- Policy creation and activation
- Approval administration
- Authority creation
- Data access
- Decision Record modification
- Audit administration
- Operational execution

## Role Accumulation

The platform must prevent separately limited roles from combining into effective God Access.

Example prohibited concentration:

```text
Database Administrator
+ Platform Security Administrator
+ Policy Administrator
+ Service Owner
+ Data Owner Delegate
+ Approval Administrator
+ Operational Executor
```

The Foundation must support:

- Incompatible authority sets
- Separation-of-duty policies
- Maximum authority concentration rules
- Independent grant approval
- Periodic access review
- Time-bounded elevation
- Revocation propagation

## Suggested Role Classes

- Database owner
- Migration role
- Application connection role
- Trust Provider role
- Security function owner
- Decision Record writer
- Decision Record reader
- Audit reader
- Reporting reader
- Streaming service reader
- Validation role

Application roles must not own protected schemas or security functions.

## Protected Operations

Protected operations should use controlled functions that:

- Validate Authorization Lease
- Verify current supporting records
- Enforce scope
- Recheck revocation
- Enforce separation of duties
- Create Decision Records
- Execute atomically where required

## Row-Level Security

RLS restricts rows within an authorized operation.

RLS does not replace the Decision Engine.

Trusted RLS context must not come from arbitrary client-set variables.

## `SECURITY DEFINER`

Every `SECURITY DEFINER` function must:

- Use an explicit fixed `search_path`
- Be owned by a non-login role
- Validate the caller
- Avoid uncontrolled dynamic SQL
- Avoid trusting raw session settings
- Record material decisions
- Return minimal failure detail

## Break-Glass Access

Emergency access must be:

- Explicit
- Time-bounded where possible
- Purpose-limited
- Independently approved
- Fully recorded
- Reviewed after use
- Unable to alter prior Decision Records

## Architectural Invariants

1. PostgreSQL independently verifies protected access.
2. No application role is a God account.
3. Role accumulation is evaluated.
4. Application roles do not own protected security objects.
5. Direct table privileges are minimized.
6. RLS is defense in depth.
7. Break-glass use is exceptional and reviewable.
8. Decision Records remain protected from ordinary administrators.
