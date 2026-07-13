# 0003 — Foundation Phase 4 Step 7 Approval Integration Boundary

> **Status:** Accepted for CAD architecture
>
> **Date:** 2026-07-13
>
> **Owner:** Iron Signal Systems

## Context

The Platform Foundation completed the Phase 4 Step 7 implementation boundary for deterministic independent-connection approval concurrency. CAD, its user interfaces, and its Operational Workstation must consume that boundary without creating client-side or module-owned substitutes for Foundation approval and authorization records.

The earlier CAD and workstation drafts contained an ambiguous local state labeled as committed, a generic approved state, broad record terminology, and offline queued actions without an explicit prohibition against manufacturing approval or authorization state.

## Decision

1. CAD consumes the Foundation's Approval Request, Approval Action Record, stage-evaluation, one-time finalization, Authority Grant continuity, Authorization Decision, Authorization Lease, Decision Record, and Decision Supporting Record contracts.
2. An approval remains a bounded policy input and never independently grants permission or commits a CAD operation.
3. A workstation may retain drafts, local records, and queued delivery intent, but it may not locally create or finalize Foundation approval or authorization state.
4. `Committed` is reserved for an authoritative CAD result acknowledged by the controlled service boundary.
5. Retryable serialization and deadlock outcomes remain distinct from policy denials.
6. CAD architecture uses exact record names rather than unqualified `evidence` where the Foundation defines a more precise artifact or record type.
7. Files under `docs/decisions/` are Architecture Decision Records and are not Foundation Decision Records.

## Consequences

- The CAD interface must display exact approval, authorization, lease, commit, and delivery states.
- Degraded workflows cannot bypass Phase 4 Step 7 current-state and concurrency controls.
- CAD tests must include revocation, withdrawal, replay, and retry distinctions.
- The workstation trust model uses Workstation Observation Records, Workstation Trust Assertions, and Foundation Decision Supporting Records.
- This decision changes no Foundation migration, test, or assertion count and does not claim formal Phase 4 acceptance beyond the completed Step 7 boundary.
