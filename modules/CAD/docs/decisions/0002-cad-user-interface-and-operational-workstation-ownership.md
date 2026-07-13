# 0002 — CAD User Interface and Operational Workstation Ownership

> **Status:** Accepted for architecture organization
>
> **Date:** 2026-07-13
>
> **Owner:** Iron Signal Systems

## Context

The original `docs/architecture/user-interface/` directory described broad,
cross-platform human-interface requirements. The original
`docs/architecture/operational-workstation/` directory described a reusable
managed operational console whose initial demanding profile was public-safety
dispatch.

After the CAD module architecture was established, both directories overlapped
substantially with CAD dispatcher workflow, accessibility, degraded operation,
and workstation implementation. Their original locations made ownership
ambiguous.

The workstation documents also used the word `module` for separately supervised
console processes. The repository now uses `module` for top-level product module
families such as CAD, creating avoidable terminology conflict.

## Decision

1. Move the user-interface architecture to:

   ```text
   modules/CAD/docs/architecture/user-interface/
   ```

2. Move the operational-workstation architecture to:

   ```text
   modules/CAD/docs/architecture/operational-workstation/
   ```

3. Narrow the user-interface documents to human-facing CAD interfaces. They no
   longer claim authority over every future Iron Signal Platform interface.

4. Narrow the Operational Workstation documents to the CAD Operational
   Workstation profile.

5. Reserve `module` for top-level Platform modules. Rename separately supervised
   local console functions to `workstation components`.

6. Keep domain, interface, and workstation authority separate according to the
   CAD Architecture Boundary and Precedence Model.

7. Preserve the existing non-production workstation examples under the CAD
   Operational Workstation directory. Rename the example component profile to
   match the new terminology.

8. Do not claim implementation, accessibility conformance, workstation
   acceptance, or production readiness because of this relocation.

## Consequences

- CAD owns its dispatcher, supervisor, responder, administrative, support, and
  workstation human-interaction architecture.
- CAD owns the first managed operational workstation profile.
- The Platform Foundation remains free of CAD presentation and workstation
  details.
- Future modules do not automatically inherit CAD-specific interaction or
  workstation rules.
- A future genuinely shared cross-module interface architecture may be promoted
  from proven reusable CAD requirements through a separate decision.
- Existing links and references must use the new module-owned paths.
- Workstation examples remain non-production and must not be deployed unchanged.
