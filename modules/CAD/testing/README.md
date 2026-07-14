# CAD Testing Registries

> **Owner:** Iron Signal Systems
>
> **Status:** Design-only authoritative registry scaffold
>
> **Production status:** Not accepted for production use

## Purpose

Provide stable machine-readable identities for controlled operations,
enforcement points, hostile classes, and test oracles before executable CAD
testing begins.

## Registries

```text
cad-controlled-operations.yaml
cad-enforcement-points.yaml
cad-hostile-classes.yaml
test-oracles.yaml
```

## Governing Documents

- `modules/CAD/docs/architecture/cad-testing-identifiers-and-authoritative-registries-model.md`
- `modules/CAD/docs/architecture/cad-test-campaign-accounting-model.md`
- `modules/CAD/docs/architecture/cad-test-oracle-and-side-effect-verification-model.md`
- `modules/CAD/docs/architecture/cad-test-execution-tiers-and-gate-cadence.md`
- `modules/CAD/docs/architecture/cad-test-evidence-retention-and-integrity-model.md`
- `modules/CAD/docs/architecture/cad-acceptance-record-model.md`

## Current Boundary

All seeded entries are proposed or design-only. Exact implementation mappings,
state selectors, tests, campaign counts, and accepted evidence remain future
work.

## Validation

A future Phase 0 gate must verify:

- YAML parses.
- Schema versions are supported.
- Identifiers are unique.
- Cross-references resolve.
- No entry claims implementation or acceptance.
- Status and source paths agree with CAD documentation.
