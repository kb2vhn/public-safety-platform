# Foundation Terminology and Domain Neutrality

> **Document status:** Normative Platform Foundation architecture.
>
> **Purpose:** Preserve terms that remain clear across public safety, municipal government, schools, finance, public works, utilities, human resources, permitting, records, and future module families.

## Five-Year Clarity Rule

A Foundation term must remain understandable to a maintainer who did not participate in its original design.

A term is acceptable only when:

1. Its meaning is defined in this document or a linked normative model.
2. It identifies one concept rather than several unrelated concepts.
3. Its database name does not imply a domain restriction that the Foundation does not have.
4. Its security meaning does not depend on informal team knowledge.
5. A module can specialize it without changing the Foundation meaning.

When a shorter term is ambiguous, the Foundation uses the longer explicit term.

## Domain-Neutral Foundation Rule

Public safety is the initial module family and a demanding source of requirements.

It does not define the limits of the Platform Foundation.

A concept belongs in the Foundation only when it:

- Establishes a shared trust, identity, authorization, accountability, governance, resilience, observability, or integration boundary;
- Is reusable across unrelated module families; or
- Provides a neutral extension point that modules specialize.

Domain records such as dispatch incidents, criminal cases, evidence custody, permits, invoices, student records, work orders, payroll records, or utility accounts belong to modules.

## Canonical Terms

### Platform Foundation

The shared domain-neutral layer that supplies cross-module security, governance, operational integrity, and integration capabilities.

### Module

A bounded set of domain functionality with explicit data ownership and controlled dependencies on Foundation capabilities.

### Module Family

A related group of modules, such as public safety, municipal administration, education, finance, public works, or utilities.

### Shared Resource

A reusable record representing a person, asset, facility, vehicle, equipment item, location, qualification, schedule, or another capability used by more than one module.

A Shared Resource is not automatically an authorization subject or a protected resource target.

### Organization

A stable legal, administrative, contractual, or operational entity.

An Organization is not inferred from a hostname, email domain, deployment, or database role.

### Organizational Unit

An internal subdivision of one Organization.

### Platform Service

A logical software capability governed by the Platform Foundation.

It does not mean a municipal public service, an operating-system daemon, or an external vendor unless a document explicitly says so.

### Deployment

A concrete running instance or environment of one Platform Service.

### Governed Scope

A stable, typed boundary used to constrain policy, authority, eligibility, approval, data handling, or a protected operation.

A Governed Scope may represent:

- A legal authority boundary;
- A geographic service area;
- A school district or campus;
- A department or facility;
- A taxing, utility, or regulatory district;
- A data-residency boundary;
- A contractual boundary;
- Another module-defined boundary.

`JURISDICTION` is a permitted module-defined `governed_scope_type`. It is not the universal Foundation field name.

### Protected Resource Target

The exact record, resource, bounded collection, or operation target affected by an authorization decision.

The word “resource” by itself is insufficient when it could mean a Shared Resource, compute resource, database object, or protected target.

### Governed Purpose

A versioned reason category recognized by authorization policy.

Free-form explanatory text may supplement a Governed Purpose but does not replace it.

### Governed Operation

A stable operation key recognized by authorization policy and implemented by a controlled operation.

### Authentication Assertion

An externally issued set of authentication claims received from a configured Trust Provider.

Its lifecycle state determines whether it is merely received, verified, rejected, expired, revoked, or consumed.

The presence of an Authentication Assertion does not grant authorization.

### Trust Provider

A configured authority that issues or validates identity, device, certificate, or authentication claims under an explicit trust configuration.

The word “provider” must not be used alone when Trust Provider is intended.

### Authorization Evaluation Process

The complete governed process that evaluates request context, applicable policy, identity, device, organization, eligibility, session, purpose, operation, governed scope, classification, authority, separation of duties, approval, lease state, and database-boundary requirements.

This term describes a process. It does not require one monolithic software component.

### Authority Definition

A governed capability recognized by the platform.

### Authority Grant

An effective-dated, revocable assignment of one Authority Definition to an identity within explicit scope.

### Access Eligibility

A current organizational or service condition that makes an identity eligible for authorization evaluation.

Eligibility is not authority.

### Approval

An attributable policy input recorded by an authorized and, when required, independent actor.

Approval is not authority.

### Authorization Lease

A short-lived, revocable, scope-bound authorization capability issued after a successful authorization evaluation.

### Protected Operation

A narrowly defined operation that may change or disclose protected state only through a controlled database or service path.

### Decision Record

The attributable record of one authorization or other material platform decision, including its exact context, policy versions, stage results, reason codes, and final result.

### Decision Explanation Chain

The ordered evaluation and supporting-record structure that explains why a Decision Record reached its final result.

### Data Classification

A governed data-handling category.

The word “classification” alone is allowed only when the surrounding context unambiguously refers to Data Classification.

### Assurance Artifact

A controlled document, test result, assessment output, attestation, log extract, or other artifact used to demonstrate control implementation or effectiveness.

Do not use the unqualified word “evidence” when Assurance Artifact is intended.

### Decision Supporting Record

A versioned record referenced by an authorization evaluation to support one stage result.

### External Monitoring System

A system such as a metrics collector, log platform, SIEM, or alerting platform that consumes canonical telemetry.

### Delivery Destination

One configured endpoint or external system to which canonical telemetry or integration events are delivered.

### Integration Contract

A versioned contract defining how one external system exchanges records or events with the platform.

### External-System Adapter

A replaceable component that translates between canonical platform records and an Integration Contract.

## Prohibited or Restricted Terms

### Provider Evidence

Prohibited.

Use **Authentication Assertion** for externally issued authentication claims.

Use **Assurance Artifact** for control-assurance material.

Use **Decision Supporting Record** for a record used by an evaluation.

### Trust Assertion

Prohibited because it can imply that the assertion is trusted merely because it exists.

Use **Authentication Assertion** and state its lifecycle status explicitly.

### Jurisdiction as a Foundation Field

Prohibited.

Use **Governed Scope**.

A module may use `JURISDICTION` as a governed scope type.

### Provider Without Qualification

Avoid.

Use the exact category:

- Trust Provider
- External Monitoring System
- Delivery Destination
- Integration Contract
- External-System Adapter
- Identity provider only when discussing an external identity protocol role

### Decision Engine

Avoid because it can mean either a conceptual process or a specific monolithic component.

Use **Authorization Evaluation Process** for the process.

Name a concrete software component by its actual service or package name.

### Operational Validation

Avoid unless the exact conditions being validated are listed.

Use the specific stage or rule name.

### Scope

Avoid when the type of scope matters.

Use Governed Scope, organization scope, service scope, approval scope, authority scope, classification scope, or protected target scope.

### Resource

Avoid when the kind of resource matters.

Use Shared Resource, compute resource, storage resource, database object, or Protected Resource Target.

### Evidence

Avoid when the category matters, especially because an Evidence and Property module may use “evidence” in a legal or custodial sense.

Use Authentication Assertion, Assurance Artifact, Decision Supporting Record, diagnostic record, source record, or another explicit category.

## SQL Naming Rules

Foundation SQL uses:

```text
governed_scope_id
governed_scope_key
governed_scope_type
organization.governed_scopes
organization.governed_scope_authorities

authentication_assertion_id
access_control.authentication_assertions
access_control.consume_authentication_assertion

integration_contract_id
integration.integration_contracts
external_system_name

destination_type
destination_reference

evaluator_name
evaluator_version
```

Names that encode one module’s vocabulary are not used as universal Foundation identifiers.

## Change Review Rule

Every Foundation review must ask:

1. Would this term make sense in a public-safety module?
2. Would it also make sense in a school, finance, permitting, public-works, utility, or human-resources module?
3. Does the term identify one security meaning?
4. Is a generic word hiding an authorization-critical distinction?
5. Could a new maintainer understand the term without oral history?

A “no” or uncertain answer requires the term to be clarified before the stage is accepted.
