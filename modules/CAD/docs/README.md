# CAD Documentation

> **Owner:** Iron Signal Systems
>
> **Status:** Normative CAD documentation under active refinement

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
- [Dispatcher Capability Catalog](requirements/dispatcher-capability-catalog.md)
- [CAD Architecture Decisions](decisions/README.md)
- [Acceptance Records](acceptance/README.md)

## Documentation Synchronization Rule

A CAD phase is not complete until the module README, architecture index,
requirements, decisions, executable paths, manifests, tests, phase gate,
acceptance record, counts, terminology, and next-step statement describe the
same repository state.

Documentation may describe planned behavior, but it must label that behavior as
planned until implementation and applicable tests are accepted.
