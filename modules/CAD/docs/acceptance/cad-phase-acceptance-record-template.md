# CAD Phase Acceptance Record — Template

> **Record identifier:** `CAD-ACC-UNASSIGNED`
>
> **Acceptance type:** `NOT_EVALUATED`
>
> **Phase or boundary:** `UNASSIGNED`
>
> **Decision:** `NOT_EVALUATED`
>
> **This template is not an acceptance record until completed and retained.**

## 1. Acceptance Identity

| Field | Value |
|---|---|
| Record identifier | `CAD-ACC-UNASSIGNED` |
| Acceptance type | `DOCUMENTATION_PHASE`, `IMPLEMENTATION_PHASE`, `RELEASE_CANDIDATE`, `FORMAL_PHASE`, `PREPRODUCTION`, `PILOT_ENTRY`, `PRODUCTION_RELEASE`, `TOPOLOGY_CHANGE`, or `RENEWAL` |
| Phase and step | |
| Decision | `NOT_EVALUATED`, `BLOCKED`, `FAILED`, `ACCEPTED`, or `ACCEPTED_WITH_EXCEPTION` |
| Decision date | |
| Supersedes | |
| Superseded by | |

## 2. Exact Boundary

### Included

- `[Complete this section.]`

### Explicitly Excluded

- `[Complete this section.]`

### Claim

State exactly what this record proves.

### Non-Claim

State what this record does not prove.

## 3. Repository and Release Identity

| Field | Value |
|---|---|
| Repository | `Iron-Signal-Systems/iron-signal-platform` |
| Branch | |
| Commit | |
| Tag | |
| Source-tree digest | |
| Artifact digest set | |
| Registry revision or digests | |
| Evidence-manifest identifier and digest | |

## 4. Environment and Topology

| Field | Value |
|---|---|
| Environment identifier | |
| Environment fingerprint | |
| Host topology | |
| Operating systems | |
| PostgreSQL version and settings fingerprint | |
| Go version and build identity | |
| Workstation profile | |
| External simulators or providers | |
| Time synchronization status | |
| Known environmental deviations | |

## 5. Executable Inventory

| Inventory | Count or identity |
|---|---|
| CAD migrations | |
| CAD manifest entries | |
| Registered controlled operations | |
| Go packages or services | |
| Workstation components | |
| Adapters | |
| Sequential tests | |
| Concurrency tests | |
| Campaign definitions | |
| Oracles | |

Use `NOT_APPLICABLE` for documentation-only acceptance.

## 6. Test Tiers

| Tier | Required | Result | Evidence |
|---|---:|---|---|
| Tier 0 — Static repository truth | | | |
| Tier 1 — Unit and model | | | |
| Tier 2 — Clean installation and sequential integration | | | |
| Tier 3 — Boundary, bypass, and concurrency | | | |
| Tier 4 — Adversarial and fault exploration | | | |
| Tier 5 — Milestone mixed-workload qualification | | | |
| Tier 6 — Candidate gate | | | |
| Tier 7 — Formal phase acceptance | | | |
| Tier 8 — Preproduction, pilot, and production qualification | | | |

## 7. Correctness and Campaign Summary

```yaml
correctness:
  pass: 0
  fail: 0
  warn: 0
  unexpected_successes: 0
  unintended_side_effects: 0
  unknown_outcomes: 0
  unclassified_failures: 0

campaigns:
  configured: 0
  generated: 0
  submitted: 0
  attempted: 0
  completed: 0
  credited_pass: 0
  excluded: 0
  invalidated: 0
  technical_retries: 0
  retry_exhaustions: 0
  attempt_budget_violations: 0
  nested_retry_violations: 0

evidence:
  required: 0
  present: 0
  missing: 0
  corrupt: 0
  telemetry_gaps: 0
```

For documentation-only Phase 0, explain why executable counters are
`NOT_APPLICABLE` rather than inventing zero-test success.

## 8. Coverage

| Coverage category | In scope | Covered | Missing | Result | Evidence |
|---|---:|---:|---:|---|---|
| Requirements | | | | | |
| Invariants | | | | | |
| Hazards | | | | | |
| Threats and abuse cases | | | | | |
| Standards clauses | | | | | |
| Controlled operations | | | | | |
| Enforcement points | | | | | |
| Positive paths | | | | | |
| Hostile classes | | | | | |
| Concurrency | | | | | |
| Failure and recovery | | | | | |
| Accessibility | | | | | |
| Performance and availability | | | | | |
| Evidence completeness | | | | | |

Do not publish one combined coverage percentage.

## 9. Hostile and Side-Effect Results

| Item | Result |
|---|---|
| Candidate minimums satisfied | |
| Formal minimums satisfied | |
| Cache and queue authority-misuse campaign | |
| Direct Go testing | |
| Direct PostgreSQL bypass testing | |
| Full-stack testing | |
| Unexpected successes | |
| Unintended side effects | |
| Unknown outcomes | |
| Oracle disagreements | |
| Permanent hostile-corpus updates | |

## 10. Concurrency, Retry, Idempotency, and Replay

| Item | Result |
|---|---|
| Independent-connection race tests | |
| Retry budget | |
| Single retry owner | |
| Backoff and jitter | |
| Retry amplification | |
| Idempotency | |
| Duplicate delivery | |
| Replay | |
| Queue and worker restart | |
| Recovery and reconciliation | |

## 11. Accessibility and Human Factors

State:

- Automated result.
- Keyboard result.
- Screen-reader or assistive-technology result.
- Critical alert equivalence.
- Map alternative.
- Focus and context stability.
- Degraded-operation accessibility.
- Manual representative-workflow result.
- Exceptions.

## 12. Resource and Performance

### Correctness Result

State separately.

### Resource Observation

Include:

- Total and phase timing.
- CPU.
- Memory.
- Disk and PostgreSQL I/O.
- WAL.
- Database size.
- Connections.
- Queues and workers.
- Workstation resources.
- Environment fingerprint.
- Trend comparison.

### Threshold Status

`OBSERVATION_ONLY`, `PASS`, `FAIL`, or `NOT_APPLICABLE`.

## 13. Availability and High Availability

| Item | Result |
|---|---|
| Availability window and result | |
| Outage ledger | |
| Critical service-path results | |
| Fourteen-day failure-free clock | |
| Credited attack-wave hours | |
| Primary host-loss events | |
| Primary network-partition events | |
| Primary process-loss events | |
| Detection | |
| Quorum and fencing | |
| Read recovery | |
| Replacement writer | |
| Protected-write recovery | |
| Reconciliation | |
| Workstation recovery | |
| Queue drainage | |
| Split-brain events | |
| Lost acknowledged commits | |
| Automatic failback | |
| Authority oscillation | |

## 14. Maintenance, Backup, Restore, and Rebuild

State results for:

- Rolling application update.
- Mixed-version operation.
- Database-node maintenance.
- Operating-system reboot cycle.
- Workstation update.
- Failed update and rollback.
- Backup.
- Restore.
- Trusted rebuild.
- Artifact revocation.
- Data migration or cutover when applicable.

## 15. Standards and Interoperability

Identify:

- Standard or profile.
- Exact edition.
- Applicable clauses.
- Tests.
- Evidence.
- Deviations.
- Acceptance status.

Do not use a broad compliance label without clause-level evidence.

## 16. Release and Supply-Chain Integrity

Identify:

- Dependency lock state.
- SBOMs.
- Build provenance.
- Build isolation.
- Artifact signatures.
- Promotion digest.
- Deployment verification.
- Package and `/etc` integrity baseline.
- Vulnerability disposition.
- Trusted rebuild and revocation status.

## 17. Findings and Defects

| Identifier | Severity | Mechanism | Affected boundary | Disposition | Evidence |
|---|---|---|---|---|---|
| | | | | | |

Every confirmed mechanism must be added to regression or receive an accepted
reason why that is not applicable.

## 18. Warnings

| Warning | Consequence | Owner | Disposition | Accepted by |
|---|---|---|---|---|
| | | | | |

## 19. Exceptions

| Exception ID | Scope | Consequence | Compensating controls | Owner | Expiration or review condition | Status |
|---|---|---|---|---|---|---|
| | | | | | | |

Expired exceptions block acceptance.

## 20. Evidence

| Evidence ID | Artifact | SHA-256 | Retention class | Storage | Verified |
|---|---|---|---|---|---|
| | | | | | |

Include the evidence-manifest digest.

## 21. Roles and Independence

| Role | Identity | Relationship to implementation | Decision |
|---|---|---|---|
| Implementation owner | | | |
| Test owner | | | |
| Oracle reviewer | | | |
| Evidence custodian | | | |
| Security reviewer | | | |
| Accessibility reviewer | | | |
| Operational reviewer | | | |
| Acceptance authority | | | |

Disclose unavoidable role overlap.

## 22. Automatic-Blocker Review

```yaml
automatic_blockers:
  unexpected_successes: 0
  unintended_side_effects: 0
  unknown_outcomes: 0
  unclassified_failures: 0
  required_evidence_missing: 0
  required_telemetry_gaps: 0
  attempt_budget_violations: 0
  nested_retry_violations: 0
  required_coverage_incomplete: false
  registry_reference_failure: false
  oracle_disagreement_unresolved: false
  split_brain_events: 0
  lost_acknowledged_commits: 0
  automatic_failback_events: 0
  authority_oscillation_events: 0
  expired_exceptions: 0
  unresolved_critical_findings: 0
  unresolved_high_impact_findings_without_accepted_disposition: 0
```

Any applicable nonzero or `true` value blocks acceptance.

## 23. Known Limitations and Explicitly Unimplemented Behavior

- `[Complete this section.]`

## 24. Decision

### Decision

`NOT_EVALUATED`, `BLOCKED`, `FAILED`, `ACCEPTED`, or
`ACCEPTED_WITH_EXCEPTION`.

### Rationale

- `[Complete this section.]`

### Conditions

- `[Complete this section.]`

## 25. Next Authorized Boundary

State the exact next phase or step. Do not authorize unrelated work.

## 26. Integrity

| Item | Value |
|---|---|
| Final record SHA-256 | |
| Evidence-manifest SHA-256 | |
| Signature or integrity mechanism | |
| Retention location | |
