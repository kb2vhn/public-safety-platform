# CAD Phase Gates

> **Owner:** Iron Signal Systems
>
> **Status:** CAD Phase 0 static gate candidate

## Phase 0 Static Gate

Run from the repository root:

```bash
./tools/validation/phase-gates/cad/validate_phase0.sh
```

The gate validates:

- Required Phase 0 files.
- Local Markdown file targets.
- YAML parsing and schema versions.
- Registry ownership and design-only status.
- 104 `CAD-DSP-*` requirement records.
- Exact synchronization with the Dispatcher Capability Catalog.
- Global identifier uniqueness.
- Controlled-operation requirement and enforcement-point references.
- Oracle operation and outcome references.
- Documentation synchronization.
- Absence of production SQL, CAD migrations, or production Go-service paths.
- Explicit nonproduction status.

## Dependency

The gate requires Python 3 and the Python `yaml` module supplied by PyYAML.

## Claim Boundary

A passing result proves repository and registry consistency only.

It does not prove:

- CAD SQL.
- CAD Go services.
- Dispatcher interface behavior.
- Operational Workstation behavior.
- Accessibility conformance.
- Runtime security.
- Availability.
- Production readiness.

A retained Phase 0 acceptance record remains required before Phase 0 is
accepted.
