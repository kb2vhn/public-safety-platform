# Platform Authorization Lease Model

## Purpose

An Authorization Lease is a short-lived PostgreSQL authorization object issued after independent database verification.

## Core Principle

Go requests. PostgreSQL decides.

## Lease Binding

A lease may bind:

- Trust Provider
- Database role
- Identity
- Device and certificate
- Session
- Service
- Organization
- Eligibility
- Assignment
- Authority Grants
- Approval state
- Purpose
- Data classification
- Organization and jurisdiction scope
- Policy versions
- Decision Record
- Issue and expiration times

## Separate Lifetimes

| Object | Typical duration |
|---|---:|
| Certificate | Days |
| Trust Assertion | Seconds |
| Eligibility | Months or policy-defined |
| Assignment or authority | Hours or policy-defined |
| Session | Policy-controlled |
| Authorization Lease | Short renewable interval |

## Maximum Expiration

A lease must not outlive any required supporting record.

## Database Time

PostgreSQL time is authoritative.

## Lease Proof

A plain UUID is insufficient.

Use protected proof of possession or transaction-local verified context.

## Connection Pooling

Trusted context must not survive into unrelated pooled requests.

## Renewal

Renewal is a new decision and requires current-state verification.

## Revocation

Revocation may result from:

- Device or certificate revocation
- Identity disablement
- Participation suspension
- Eligibility revocation
- Assignment end
- Approval withdrawal
- Authority revocation
- Policy change
- Classification change
- Trust Provider revocation

## Architectural Invariants

1. Only PostgreSQL issues leases.
2. Lease creation requires independent verification.
3. Lease duration is short.
4. PostgreSQL time is authoritative.
5. Renewal is a new decision.
6. Revocation takes effect before natural expiration.
7. A plain UUID is not proof.
8. Every lease event creates a Decision Record.
