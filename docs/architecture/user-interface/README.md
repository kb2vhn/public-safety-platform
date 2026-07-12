# User-Interface Architecture

> **Status:** Normative cross-platform architecture under active refinement.

## Purpose

This directory defines the shared requirements for human-facing Platform interfaces.

A user interface exists to help a person perform an authorized role. It must complement the work, preserve attention, reduce avoidable effort, and make the state and result of the work understandable. It must not become an obstacle that the user must repeatedly overcome to complete ordinary responsibilities.

> **The interface should support the work rather than become additional work.**

These requirements apply across:

- Operational interfaces,
- Administrative applications,
- Public and community portals,
- Employee applications,
- Mobile interfaces,
- Shared terminals and kiosks,
- Authentication and session interfaces,
- Reports, forms, notices, and generated documents,
- Installation, recovery, and support interfaces,
- Other human-facing Platform capabilities.

## Architectural Boundary

This directory is deliberately technology-neutral and domain-neutral.

It defines what a responsible interface must accomplish for a person. It does not prescribe a particular:

- Programming language,
- Rendering engine,
- Desktop environment,
- Web framework,
- Mobile framework,
- Window layout,
- Module family,
- Operational role,
- Vendor product.

Role-specific workflows, implementation technology, workstation behavior, module isolation, device management, deployment topology, and performance budgets remain in the architecture area that owns them.

The user interface may consume services, decisions, policies, and governed state provided by the Platform. It must not:

- Move presentation-specific concepts into the domain-neutral Platform Foundation,
- Treat visibility of a control as authorization to perform its action,
- Allow presentation logic to bypass governed policy,
- Require users to understand internal service, database, or vendor boundaries,
- Conceal stale, uncertain, failed, or degraded state,
- Transfer avoidable implementation complexity to the person doing the work.

## Dependency Direction

```text
Platform Foundation
        ↓
Platform Services and Shared Resources
        ↓
Module Families
        ↓
User Interfaces
```

The interface presents and supports governed capabilities. It does not independently create identity, authority, approval, commitment, or truth.

## Governing Principles

1. **The role and its work come first.**
2. **The interface must preserve attention rather than compete for it.**
3. **Common work should have a clear and direct path.**
4. **System state and action outcomes must be understandable.**
5. **A failure in one capability should not unnecessarily block unrelated work.**
6. **Accessibility is part of functional correctness.**
7. **Security must remain strong without creating needless friction.**
8. **The interface must not claim success before the Platform confirms success.**
9. **The user must be able to recognize degraded, stale, queued, uncertain, rejected, and committed conditions.**
10. **Visual polish is not a substitute for effective, safe, and independently operable work.**

## Documents

- [Client Experience Model](client-experience-model.md)
- [Accessibility and Inclusive Interaction Model](accessibility-and-inclusive-interaction-model.md)

The legacy filename [Client Experience and Accessibility Model](client-experience-and-accessibility-model.md) is retained only as a compatibility index for existing links. It does not duplicate the normative requirements.
