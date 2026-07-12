# Foundation Terminology and Domain Neutrality

> **Document status:** Normative Platform Foundation architecture.
>
> **Purpose:** Preserve terminology that remains understandable across public
> safety, municipal government, schools, finance, public works, utilities,
> human resources, permitting, records, and future module families.

## Five-Year Clarity Rule

A Foundation term must remain understandable to a maintainer who did not
participate in its original design.

A term is acceptable only when:

1. Its meaning is defined here or in a linked normative model.
2. It identifies one concept rather than several unrelated concepts.
3. Its database name does not imply a domain restriction the Foundation does
   not have.
4. Its security meaning does not depend on informal team knowledge.
5. A module can specialize it without changing the Foundation meaning.

When a shorter term is ambiguous, the Foundation uses the longer explicit
term.

## Canonical Terms

### Platform Foundation

The shared domain-neutral layer that supplies cross-module security,
governance, operational integrity, and integration capabilities.

### Module

A bounded set of domain functionality with explicit data ownership and
controlled dependencies on Foundation capabilities.

### Module Family

A related group of modules, such as public safety, municipal administration,
education, finance, public works, or utilities.

### Shared Resource

A reusable record representing a person, asset, facility, vehicle, equipment
item, location, qualification, schedule, or another capability used by more
than one module.

A Shared Resource is not automatically an authorization subject or a
Protected Resource Target.

### Organization

A stable legal, administrative, contractual, or operational entity.

### Organizational Unit

An internal subdivision of one Organization.

### Platform Service

A logical software capability governed by the Platform Foundation.

It does not mean a municipal public service, operating-system daemon, or
external vendor unless a document explicitly says so.

### Deployment

A concrete running instance or environment of one Platform Service.

### Governed Scope

A stable, typed boundary used to constrain policy, authority, eligibility,
approval, data handling, or a Protected Operation.

`JURISDICTION` is a permitted module-defined `governed_scope_type`. It is not
the universal Foundation field name.

### Protected Resource Target

The exact record, resource, bounded collection, or operation target affected
by an authorization decision.

The unqualified word “resource” is insufficient when it could mean a Shared
Resource, compute resource, database object, or protected target.

### Governed Purpose

A versioned reason category recognized by authorization policy.

Free-form explanatory text may supplement a Governed Purpose but does not
replace it.

### Governed Operation

A stable operation key recognized by authorization policy and implemented by
a controlled operation.

### Authentication Assertion

An externally issued set of authentication claims received from a configured
Trust Provider.

Its lifecycle state identifies whether it is:

- `RECEIVED`
- `VERIFIED`
- `CONSUMED`
- `REJECTED`
- `EXPIRED`
- `REVOKED`

An Authentication Assertion is an authentication input. Its existence does
not grant authorization.

### Trust Provider

A configured authority that issues or validates identity, device,
certificate, or authentication claims under an explicit trust configuration.

The word “provider” must not be used alone when Trust Provider is intended.

### Authorization Evaluation Process

The governed process that evaluates request context, applicable policy,
identity, device, organization, eligibility, session, purpose, operation,
Governed Scope, Data Classification, authority, separation of duties,
approval, lease state, and database-boundary requirements.

This term describes a process. It does not require one monolithic software
component.

### Authority Definition

A governed capability recognized by the platform.

### Authority Grant

An effective-dated, revocable assignment of one Authority Definition to an
identity within explicit organization, service, purpose, operation, Governed
Scope, and Protected Resource Target boundaries.

### Access Eligibility

A current organizational or service condition that makes an identity eligible
for authorization evaluation.

Eligibility is not authority.

### Approval

An attributable policy input recorded by an authorized and, when required,
independent actor.

Approval is not authority.

### Authorization Lease

A short-lived, revocable, context-bound authorization capability issued after
a successful authorization evaluation.

### Protected Operation

A narrowly defined operation that may change or disclose protected state only
through a controlled database or service path.

### Decision Record

The attributable record of one authorization or other material platform
decision, including exact context, policy versions, stage results, reason
codes, and final result.

### Decision Explanation Chain

The ordered evaluation and supporting-record structure that explains why a
Decision Record reached its final result.

### Assurance Artifact

A controlled document, test result, assessment output, attestation, log
extract, or other artifact used to demonstrate control implementation or
effectiveness.

Do not use the unqualified word “evidence” when Assurance Artifact is
intended.

### Decision Supporting Record

A versioned record referenced by an authorization evaluation to support one
stage result.

### External Monitoring System

A system such as a metrics collector, log platform, SIEM, or alerting platform
that consumes canonical telemetry.

### Delivery Destination

One configured endpoint or external system to which canonical telemetry or
integration events are delivered.

### Integration Contract

A versioned contract defining how one external system exchanges records or
events with the platform.

### External-System Adapter

A replaceable component that translates between canonical platform records
and an Integration Contract.

## Prohibited or Restricted Terms

### Provider Evidence

Prohibited.

Use:

- Authentication Assertion for authentication claims;
- Assurance Artifact for control-assurance material; or
- Decision Supporting Record for a record used by an evaluation.

### Trust Assertion

Prohibited because it can imply that an assertion is trusted merely because
it exists.

Use Authentication Assertion and state its lifecycle status explicitly.

### Jurisdiction as a Foundation Field

Prohibited.

Use Governed Scope.

A module may use `JURISDICTION` as a governed scope type.

### Provider Without Qualification

Avoid.

Use the exact category:

- Trust Provider
- External Monitoring System
- Delivery Destination
- Integration Contract
- External-System Adapter
- Identity provider only when discussing an external identity-protocol role

### Decision Engine

Avoid because it can mean either a conceptual process or a specific
monolithic component.

Use Authorization Evaluation Process for the process.

Name a concrete software component by its actual service or package name.

### Scope

Avoid when the type of scope matters.

Use Governed Scope, organization scope, service scope, approval scope,
authority scope, classification scope, or Protected Resource Target.

### Resource

Avoid when the kind of resource matters.

Use Shared Resource, compute resource, storage resource, database object, or
Protected Resource Target.

### Evidence

Avoid when the category matters, especially because an Evidence and Property
module may use “evidence” in a legal or custodial sense.

Use Authentication Assertion, Assurance Artifact, Decision Supporting Record,
diagnostic record, source record, or another explicit category.

## Transitional Compatibility Names

The pre-stable Foundation may temporarily retain a legacy name only when
removing it in the same change would make existing validation fixtures
unusable.

A retained compatibility field must:

1. Be marked deprecated in its SQL comment.
2. Never be used by new authorization functions.
3. Have an explicit replacement field.
4. Be removed before the first stable migration baseline.
5. Be covered by a tracked cleanup decision.

`scope_reference` is such a transitional compatibility field. New code must
use explicit `governed_scope_id`, `protected_target_type`, and
`protected_target_reference` fields.

## SQL Naming Rules

Canonical Foundation SQL uses:

```text
governed_scope_id
governed_scope_key
governed_scope_type
organization.governed_scopes
organization.governed_scope_authorities

authentication_assertion_id
access_control.authentication_assertions
access_control.consume_authentication_assertion

trust_provider_identity_mapping_id
external_subject_identifier

operation_key
protected_target_type
protected_target_reference

integration_contract_id
external_system_name
destination_type
destination_reference

evaluator_name
evaluator_version
```

Names that encode one module’s vocabulary are not used as universal
Foundation identifiers.
