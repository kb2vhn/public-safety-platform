## Domain-Neutral Foundation Principle

The Platform Foundation must remain independent of any single operational domain.

Public safety is the initial implementation focus and may provide the first real-world requirements used to test the Foundation. Those requirements must be generalized before they become Foundation concepts.

A concept belongs in the Foundation only when at least one of the following is true:

1. It is required to establish trust, identity, authorization, accountability, governance, resilience, or another shared platform boundary.
2. It is broadly reusable across multiple unrelated module families.
3. It provides a neutral extension point through which modules can define domain-specific behavior.
4. It is required to preserve consistent security or historical guarantees across the entire platform.

A concept does not belong in the Foundation merely because the first public-safety module requires it.

Domain-specific terminology, records, workflows, and policies belong in their applicable modules.

The Foundation may define neutral abstractions such as:

* Organization
* Organizational unit
* Platform service
* Deployment
* Identity
* Device
* Session
* Purpose
* Governed operation
* Governed scope
* Resource target
* Data classification
* Approval policy
* Authorization policy
* Authorization Lease
* Decision Record
* Lifecycle event
* Governed document
* Control
* Risk
* Workload
* Integration event

Modules may specialize these abstractions.

For example:

* A public-safety module may use a governed scope to represent a legal governed scope, mutual-aid area, precinct, response district, or service area.
* A school module may use a governed scope to represent a district, school, campus, department, program, or grade boundary.
* A municipal module may use a governed scope to represent a town, department, facility, taxing district, utility district, or regulatory area.

The Foundation must not require every governed scope to be geographic, legal, or public-safety-specific.

When a proposed Foundation term is strongly associated with one domain, the design must determine whether:

1. The concept should remain entirely inside that module;
2. The concept should be replaced by a neutral Foundation abstraction; or
3. The Foundation should provide an extension mechanism through which the module defines it.

The burden is on the design to justify why a domain-specific concept belongs in the shared Foundation.

