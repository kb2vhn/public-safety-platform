# Platform Boundaries

> **Document status:** Normative Platform Foundation architecture.
>
> **Implementation status:** The Foundation SQL migrations provide an initial structural implementation. A requirement described here is not considered fully enforced until the applicable database controls, deployment roles, runtime behavior, automated tests, and operational safeguards are in place.

## Purpose

Define what belongs in the reusable Platform Foundation and prevent domain, provider, and deployment concerns from leaking into it.

## Architectural Requirements

### Included in the Foundation

The Foundation owns reusable capabilities for identity references, device trust, organizations, jurisdictions, platform services, participation, federation, attestations, approvals, authority, sessions, Authorization Leases, decision records, classification, governed documents, lifecycle history, controls, compliance mappings, assurance, risk, resilience, workload governance, observability, and integration delivery state.

### Excluded from the Foundation

The Foundation does not own dispatch incidents, units, calls for service, case reports, criminal records, evidence custody, personnel scheduling, payroll, fleet maintenance, Fire/EMS clinical workflow, vendor-specific payloads, or user-interface behavior.

### Dependency Rule

Operational modules may depend on Foundation identifiers and controlled APIs. Foundation schemas must not reference domain tables or require a particular provider.

### Data Ownership

Each domain owns its business records. The Foundation owns only the cross-domain trust, policy, governance, and accountability records necessary to evaluate or explain protected actions.

### Enforcement Boundary

PostgreSQL enforces database-level invariants. Runtime services enforce protocol, orchestration, external identity-provider interaction, and user-facing workflow. Deployment controls protect the host, credentials, backups, logs, and recovery process.

### Shared Infrastructure

Multiple organizations may share infrastructure without sharing authority. Organization and jurisdiction scope must remain explicit in every protected relationship.

## SQL Implementation Mapping

Migrations `000–099` define the current Foundation range. Later migration ranges are reserved for operational resources and domain modules. The exact range allocation is maintained in `sql-migration-map.md`.

The migration mapping identifies the current structural implementation. It does not, by itself, prove that every requirement in this document is operationally enforced.

## Validation Expectations

The Foundation SQL test framework must test the requirements that can be demonstrated at the database boundary. Runtime, deployment, recovery, and provider behavior must be tested in their respective layers.

## Related Documents

- [SQL Migration Map](sql-migration-map.md)
- [Database Security](database-security-model.md)
- [Organization and Jurisdiction](organization-and-jurisdiction-model.md)
