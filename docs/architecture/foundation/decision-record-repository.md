# Platform Decision Record Repository

## Purpose

The Decision Record Repository is the authoritative store of decisions and Justification Chains.

It is not merely a log, SIEM, or evidence repository.

## Decision Record Contents

- Decision identifier
- Parent and correlation identifiers
- Requested operation
- Final result
- Request and decision timestamps
- Identity, device, session, and provider
- Service and organization
- Eligibility, assignment, authority, approval, purpose, and classification
- Organization and jurisdiction scope
- Policy, agreement, and governed-document versions
- Engine, build, database, and schema versions
- Authorization Lease
- Evaluation duration
- Historical context snapshot

## Evaluation Record Contents

- Evaluation identifier
- Parent evaluation
- Order
- Required or optional status
- Result
- Reason code
- Human-readable explanation
- Supporting record references
- Supporting record versions
- Policy and rule references
- Evaluating engine and version
- Timestamp and duration

## Result Requirements

### PASS

Requires authoritative records proving the condition.

### FAIL

Records expected state, actual state, and reason.

### NOT_REQUIRED

References the exact rule making the stage unnecessary.

### NOT_EVALUATED

Records why evaluation did not occur.

## Append-Only Principle

Material Decision Records and evaluation records are append-only.

Corrections and reviews create linked records.

## Protection from Administrators

Ordinary platform, service, security, and application administrators must not be able to rewrite prior Decision Records.

## Integrity

Controls may include:

- Canonical serialization
- Record hashing
- Hash linkage
- Signatures
- External integrity checkpoints
- Restricted insert functions
- Role separation

## Architectural Invariants

1. Every significant decision creates a Decision Record.
2. Every required evaluation has a result.
3. Pass and fail results are both preserved.
4. Records are append-only.
5. Historical context remains reconstructable.
6. Reusable secrets are never stored.
7. Ordinary administrators cannot alter prior meaning.
8. External systems do not replace the repository.
