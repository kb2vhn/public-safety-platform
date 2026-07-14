# CAD Machine-Readable Requirements

> **Status:** Design-only authoritative register scaffold

## Authority

```text
cad-requirements.yaml
```

The register contains the current human-facing `CAD-DSP-*` requirements from:

```text
modules/CAD/docs/requirements/dispatcher-capability-catalog.md
```

## Current Meaning

- Requirement status may be `ACTIVE`.
- Implementation status remains `NOT_IMPLEMENTED`.
- Test and acceptance status remain `NOT_TESTED`.
- Empty mappings identify work that must be completed before implementation
  acceptance.
- The file does not create SQL, Go, workstation, deployment, or production
  acceptance.

## Validation

A future static gate must verify YAML parsing, unique identifiers, required
fields, source synchronization, and cross-registry references.
