# DNP Project Naming and Identity Transition

> **Owner:** Iron Signal Systems
>
> **Status:** Normative project-identity decision
>
> **Effective date:** 2026-07-19
>
> **Scope:** Public project identity and branding only

## Decision

The canonical project and product name is:

```text
DNP
```

The canonical expansion is:

```text
Domain-Neutral Platform
```

The company and project owner remains:

```text
Iron Signal Systems
```

The preferred complete public form is:

```text
DNP — Domain-Neutral Platform
```

“DNP” may be used after the complete form has been established in the document,
interface, release, or conversation.

## Product and Architecture Relationship

DNP is the top-level project and product identity.

The Domain-Neutral Platform Foundation is the shared security, governance,
identity, authorization, resilience, observability, integration, and resource
governance foundation used by operational module families.

Public safety remains the first planned module family. Computer Aided Dispatch
remains the first planned operational module. This naming decision does not
move public-safety or CAD concepts into the Foundation.

## Company Attribution

DNP is an Iron Signal Systems project.

The company line remains:

> **Built on purpose. Backed by discipline. Engineered to endure.**

## Repository Identity

The existing repository remains:

```text
Iron-Signal-Systems/iron-signal-platform
```

This branding change does not rename the GitHub repository, local checkout,
Git remote, Go module path, deployment paths, or automation references.

A repository rename is a separate governed change because it affects clone URLs,
developer workstations, documentation, CI/CD, deployment tooling, release
automation, integrations, and external references.

## Historical Integrity

Historical acceptance records, signed or annotated tags, commit identifiers,
test evidence, validation output, schema-version identifiers, and frozen
technical contracts must not be rewritten merely to apply the new project name.

Historical material may retain “Iron Signal Platform,” “ISSP,” or other
previously accepted identifiers when those names identify the exact system,
artifact, schema, role, executable, service, or evidence contract that was
validated at that time.

Current documentation may explain that DNP is the successor public identity,
but it must not falsely present historical evidence as having been produced
under a name or identifier that did not exist at the time.

## Technical-Identifier Transition

This branding change intentionally does not mass-replace technical identifiers,
including examples such as:

- `issp_*` PostgreSQL roles and database identifiers
- service users and capability roles
- systemd units
- executable names
- environment-variable names
- schema-version identifiers
- test fixtures and phase-gate assertions
- accepted tag names
- repository and filesystem paths

Any later technical-identifier migration must include:

1. A complete identifier inventory.
2. Compatibility and coexistence rules.
3. Upgrade and rollback procedures.
4. Database, service, deployment, and workstation migration sequencing.
5. Updated tests and validation gates.
6. Documentation updates in the same change set.
7. Explicit preservation of historical evidence.
8. Formal acceptance before obsolete identifiers are removed.

## Branding Asset

The primary DNP badge is stored at:

```text
docs/assets/branding/dnp-platform-badge.png
```

Recommended Markdown use:

```html
<p align="center">
  <img
    src="docs/assets/branding/dnp-platform-badge.png"
    alt="DNP — Domain-Neutral Platform Foundation badge"
    width="760"
  >
</p>
```

The asset is project branding supplied by the Iron Signal Systems project owner.
