# 0001 — CAD Module Name and Repository Boundary

> **Status:** Accepted for this design scaffold
>
> **Date:** 2026-07-13
>
> **Owner:** Iron Signal Systems

## Context

The repository defines Computer Aided Dispatch as the first planned operational
module while keeping the Platform Foundation domain-neutral.

A stable module home is needed for CAD-specific architecture, requirements,
decisions, and future acceptance records.

The current repository already has authoritative top-level implementation trees
for SQL, tests, Go, and validation. Creating a second implementation framework
inside the module folder would duplicate those controls.

## Decision

1. The root module-family directory is:

   ```text
   modules/
   ```

2. The Computer Aided Dispatch module directory is named exactly:

   ```text
   modules/CAD/
   ```

3. `modules/CAD/` is the normative module home for:

   - Mission and scope.
   - Architecture.
   - Requirements.
   - Decisions.
   - Acceptance records.
   - Cross-links to executable artifacts.

4. Future executable artifacts remain in the repository's authoritative
   implementation trees, using lower-case implementation identifiers unless a
   later decision establishes otherwise.

5. This decision does not allocate a migration range and does not authorize
   production SQL, Go, interface, adapter, or deployment work.

## Consequences

- CAD-specific meaning remains outside the Platform Foundation.
- The module has a clear architectural home.
- Existing manifest, test-runner, and phase-gate patterns remain reusable.
- Future changes can be traced from requirement to implementation and
  acceptance.
- The root repository indexes may link to this module without moving CAD
  concepts into Foundation documentation.
