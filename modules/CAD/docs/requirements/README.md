# CAD Requirements

> **Owner:** Iron Signal Systems
>
> **Status:** Normative requirements documentation under active refinement
>
> **Implementation status:** Requirements and traceability design only

## Purpose

Maintain human-readable CAD requirements and bind them to the authoritative
machine-readable register before implementation and acceptance claims begin.

## Documents

- [Dispatcher Capability Catalog](dispatcher-capability-catalog.md)
- [CAD Requirements and Evidence Traceability Model](cad-requirements-traceability-model.md)

## Authoritative Register

```text
modules/CAD/requirements/cad-requirements.yaml
```

The current register seeds the existing `CAD-DSP-*` requirements from the
Dispatcher Capability Catalog. It does not claim that those requirements are
implemented, tested, or accepted.

## Rule

Human-readable requirement text and machine-readable records must remain
synchronized. A static gate must fail on missing identifiers, duplicate
identifiers, unresolved mappings, or contradictory status.
