# CAD Test Execution Tiers and Gate Cadence

> **Owner:** Iron Signal Systems
>
> **Module:** Computer Aided Dispatch
>
> **Document status:** Normative CAD assurance architecture
>
> **Implementation status:** Test-tier design only
>
> **Production status:** Not accepted for production use

## Purpose

Provide fast development feedback without weakening formal CAD assurance.

Not every change requires a complete fourteen-day, 180-hour, 10,000-attempt,
high-availability qualification run. Every change does require the highest
applicable tier before the corresponding claim is accepted.

## Principles

1. Lower tiers provide earlier feedback.
2. Higher tiers include or supersede applicable lower-tier evidence.
3. A lower-tier pass never substitutes for a required higher-tier pass.
4. Formal campaign minimums are not reduced to fit development cadence.
5. Tests are assigned to tiers by consequence, boundary, and execution cost.
6. Correctness and resource observations remain separate.
7. A test may run in several tiers with different counts or environments.
8. Every accepted result identifies the exact tier, source revision, registry
   revision, environment, and evidence manifest.

## Tier 0 — Static Repository Truth

**Trigger:** Every documentation or registry change.

**Scope:**

- Required paths and files.
- Markdown links.
- YAML parsing.
- Supported schema versions.
- Identifier uniqueness.
- Reference resolution.
- Status-language consistency.
- Forbidden placeholders and secrets.
- File hygiene.
- Generated-file provenance.
- No unsupported implementation or production claim.
- Phase counts and next-boundary statements.
- Acceptance-record structure.

**Environment:** Repository only.

**Acceptance use:** Phase 0 documentation acceptance and prerequisite for every
higher tier.

## Tier 1 — Deterministic Unit and Model Tests

**Trigger:** Every affected package, state model, parser, validator, generator,
or reference-model change.

**Scope:**

- Pure Go unit tests.
- Deterministic state-machine tests.
- Parser and canonicalization tests.
- Registry validators.
- Test-generator self-tests.
- Oracle self-tests.
- Property checks that need no external service.
- Accessibility logic that can be tested without rendering.
- Retry calculation and budget logic.

**Environment:** Reproducible local or CI build environment.

## Tier 2 — Clean Installation and Sequential Integration

**Trigger:** Every schema, controlled API, service persistence, or migration
change.

**Scope:**

- Unique disposable database.
- Authoritative manifests in dependency order.
- Structural and catalog validation.
- Ownership, privilege, security-definer, search-path, and RLS checks.
- Sequential positive behavior.
- Sequential denial behavior.
- Idempotency and replay basics.
- Exact cleanup.
- Resource observation when an executable path changes.

**Environment:** Disposable same-version development topology.

## Tier 3 — Boundary, Bypass, and Concurrency

**Trigger:** Every protected operation, authorization boundary, queue, worker,
or race-sensitive change.

**Scope:**

- Direct Go rejection tests.
- Direct PostgreSQL bypass tests.
- Full-stack service-to-database tests.
- Independent-connection concurrency.
- State-version and winner-selection races.
- Queue redelivery and worker restart.
- Bounded retry and deadlock behavior.
- Side-effect oracles.
- Cross-context isolation.
- Cache and queue authority-misuse checks where applicable.

**Environment:** Disposable multi-connection topology with retained failure
state.

## Tier 4 — Nightly Adversarial and Fault Exploration

**Trigger:** Scheduled against the active development line and after material
security changes.

**Scope:**

- Random hostile generation.
- Fuzz and mutation.
- Retry storms.
- Cancellation and timeout.
- Queue, spool, outbox, and replay misuse.
- Process restart.
- Provider duplication, delay, and reordering.
- Initial resource-pressure exploration.
- Permanent hostile-regression corpus.
- Failure-mechanism discovery.

**Environment:** Isolated nonproduction environment.

Tier 4 may discover new classes. It does not by itself establish candidate or
formal minimum-count acceptance.

## Tier 5 — Milestone Mixed-Workload Qualification

**Trigger:** Feature milestone or accepted phase candidate preparation.

**Scope:**

- Representative normal CAD workflows.
- Multiple hostile families.
- Mixed concurrency.
- Fault injection.
- Degraded-operation behavior.
- Accessibility workflows.
- Server and workstation telemetry.
- Capacity and queue observations.
- Backup, restore, rollback, or reconciliation when affected.
- Campaign-validity checks.

**Environment:** Representative test topology with complete fingerprints.

## Tier 6 — Candidate Gate

**Trigger:** Phase or release candidate.

**Scope:**

- All applicable lower tiers.
- At least 1,000 completed credited hostile attempts for every required hostile
  class at every applicable enforcement point.
- Candidate mixed-stress gate.
- Complete requirement, invariant, operation, enforcement-point, hostile-class,
  and evidence coverage.
- Zero unexpected successes.
- Zero unintended side effects.
- Zero unknown outcomes.
- Complete telemetry.
- Candidate acceptance record.

**Environment:** Accepted candidate topology.

A candidate result is not formal phase acceptance.

## Tier 7 — Formal Phase Acceptance

**Trigger:** Formal acceptance of an executable CAD phase.

**Scope:**

- All applicable lower tiers.
- At least 10,000 completed credited hostile attempts for each required
  high-impact operation at every applicable enforcement point.
- At least 10,000 completed credited attempts for every required hostile class.
- Formal retry-storm, concurrency, fault, recovery, and evidence requirements.
- Independent review.
- Signed or otherwise integrity-bound acceptance record.
- Exact release, artifact, schema, registry, and environment identity.

**Environment:** Accepted formal-assurance topology.

## Tier 8 — Preproduction, Pilot, and Production Qualification

**Trigger:** Pilot entry, production release, material topology change, or
production-readiness renewal.

**Scope:**

- Operational-readiness model.
- Fourteen-consecutive-day failure-free requirement.
- At least 180 credited attack-wave hours across the required observation
  period.
- At least 99.99 percent availability over the accepted window.
- HA failover, fencing, stable-primary, anti-oscillation, and former-primary
  rejoin.
- One-failure capacity and queue drainage.
- Rolling maintenance and mixed-version operation.
- Backup, restore, trusted rebuild, and rollback.
- Release integrity, SBOM, provenance, signatures, package and host identity.
- Pilot and operational acceptance where applicable.

**Environment:** Production-representative preproduction or governed pilot
topology.

## Test Metadata

Every registered test must eventually identify:

```text
test identifier
title
owner
requirements
invariants
hazards and threats
controlled operations
hostile or failure classes
enforcement points
oracle
minimum tier
candidate applicability
formal applicability
preproduction applicability
environment needs
resource-observation status
accessibility status
evidence outputs
```

## Promotion Rules

A change may advance only when:

- Its required current tier passes.
- Required lower tiers remain passing.
- Coverage mappings are complete.
- No hidden exclusion or invalidated evidence is used.
- Warnings are understood.
- Resource observations are recorded separately.
- New defects or hostile mechanisms have dispositions.
- Registry and documentation status matches the executable state.

A failed higher tier may require rerunning lower tiers when root-cause analysis
shows their assumptions were incomplete.

## Regression Selection

Impact analysis may select a focused lower-tier subset during development.
Formal gates must use the full applicable accepted inventory.

Regression selection must consider:

- Changed files.
- Changed requirements.
- Changed registry entries.
- Dependency graph.
- Shared invariants.
- Shared state selectors.
- Shared enforcement points.
- Prior defects and hostile corpus.
- Migration and mixed-version effects.
- Workstation and external-adapter effects.

## Performance Thresholds

Observation-only telemetry may run in Tiers 2 through 5.

A performance result becomes pass/fail only after the workload, topology,
measurement method, baseline population, variation, operational budget, margin,
and response to failure are accepted.

Correctness failures may never be waived because performance improved.

## Acceptance

This tier model is accepted only when the test runner, phase gates, and
acceptance records identify the same tier meanings and no lower-tier result is
presented as stronger evidence than it is.
