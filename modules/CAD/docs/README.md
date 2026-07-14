# CAD Documentation

> **Owner:** Iron Signal Systems
>
> **Status:** Normative CAD documentation under active refinement
>
> **Implementation status:** Design and assurance metadata only

## Purpose

Govern the Computer Aided Dispatch module before production SQL, service code,
integrations, dispatcher interfaces, or Operational Workstation implementation
begin.

## Architecture Layers

```text
Platform Foundation and governed shared capabilities
        ↓
CAD domain and application architecture
        ↓
CAD user-interface architecture
        ↓
CAD Operational Workstation implementation profile
```

The layers are related but not interchangeable. The
[CAD Architecture Boundary and Precedence Model](architecture/cad-architecture-boundary-and-precedence-model.md)
defines which layer owns each kind of rule.

## Start Here

- [Architecture Index](architecture/README.md)
- [CAD User-Interface Architecture](architecture/user-interface/README.md)
- [CAD Operational Workstation Architecture](architecture/operational-workstation/README.md)
- [CAD Requirements Index](requirements/README.md)
- [Dispatcher Capability Catalog](requirements/dispatcher-capability-catalog.md)
- [CAD Requirements and Evidence Traceability Model](requirements/cad-requirements-traceability-model.md)
- [CAD Testing and Acceptance Model](architecture/cad-testing-and-acceptance-model.md)
- [CAD Testing Identifiers and Authoritative Registries Model](architecture/cad-testing-identifiers-and-authoritative-registries-model.md)
- [CAD Test Campaign Accounting Model](architecture/cad-test-campaign-accounting-model.md)
- [CAD Test-Oracle and Side-Effect Verification Model](architecture/cad-test-oracle-and-side-effect-verification-model.md)
- [CAD Test Execution Tiers and Gate Cadence](architecture/cad-test-execution-tiers-and-gate-cadence.md)
- [CAD Test Evidence Retention and Integrity Model](architecture/cad-test-evidence-retention-and-integrity-model.md)
- [CAD Acceptance Record Model](architecture/cad-acceptance-record-model.md)
- [CAD Operational Readiness and Production Acceptance Model](architecture/cad-operational-readiness-and-production-acceptance-model.md)
- [CAD Standards-Conformance and Interoperability Model](architecture/cad-standards-conformance-and-interoperability-model.md)
- [CAD Architecture Decisions](decisions/README.md)
- [Acceptance Records](acceptance/README.md)

## Machine-Readable Assurance Registries

```text
modules/CAD/requirements/cad-requirements.yaml
modules/CAD/testing/cad-controlled-operations.yaml
modules/CAD/testing/cad-enforcement-points.yaml
modules/CAD/testing/cad-hostile-classes.yaml
modules/CAD/testing/test-oracles.yaml
```

These files establish stable design identities and traceability scaffolding.
They do not create executable CAD behavior or production acceptance.

## Documentation Synchronization Rule

A CAD phase is not complete until the module README, architecture index,
requirements, decisions, registries, executable paths, manifests, tests, phase
gate, acceptance record, counts, terminology, and next-step statement describe
the same repository state.

Documentation may describe planned behavior, but it must label that behavior as
planned until implementation and applicable tests are accepted.
