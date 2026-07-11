# Public Safety Platform

> **Development status: Pre-alpha Platform Foundation**
>
> The repository began with public safety as its first operational focus.
> Current development is focused on a domain-neutral Platform Foundation that
> can support public safety, municipal government, schools, and other module
> families. The SQL is active work being completed in deliberate stages. This
> repository is not ready for production use.

## Project Mission

Every important decision should have an explanation.

Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.

The ultimate measure of success is not the number of features implemented, but whether the people who depend on the system can trust it when it matters most.

## Platform Scope and Long-Term Direction

Public safety remains the planned first module family, but it does not define
the limits of the Platform Foundation.

The Platform Foundation is domain-neutral. It provides shared:

- Trust and cryptographic boundaries
- Identity and device records
- Authentication Assertion handling
- Sessions
- Organizations and Governed Scopes
- Governed Purposes and Governed Operations
- Authority Grants
- Approval policies and actions
- Authorization Policies
- Authorization Leases
- Decision Records and Decision Explanation Chains
- Data classification and information governance
- Compliance and assurance structures
- Resilience and recovery structures
- Observability and integration structures
- Resource and workload governance

Future module families may include:

- Public safety
- Municipal administration
- Finance and budgeting
- Human resources
- Permitting and licensing
- Code enforcement
- Property and asset management
- Fleet and public works
- Utility operations and billing
- School and educational administration
- Other local-government or institutional services

Domain-specific records and workflows belong in their modules.

A public-safety legal or geographic authority boundary, for example, is a
Governed Scope whose module-defined type may be `JURISDICTION`. Jurisdiction
is not imposed as a universal Foundation concept.

The long-term objective is to let small municipalities, schools, and similar
organizations add or replace operational modules without rebuilding the
security, authorization, governance, and historical-accountability foundation
for every application.

## Initial Module Direction

Public safety is the first demanding implementation target.

Potential public-safety modules include:

- Computer Aided Dispatch
- Records Management
- Evidence and Property
- Personnel Operations
- Fleet Management
- Fire and EMS Operations

Computer Aided Dispatch is planned as the first operational module, but CAD
does not define the platform.

The Foundation must not acquire dependencies on CAD, RMS, Evidence and
Property, Fire, EMS, education, permitting, finance, utilities, or another
module family.

## Current Development Stage

Development is presently focused on the Platform Foundation.

Current work includes:

- Normative Foundation architecture documentation
- Manifest-driven PostgreSQL migrations `000–099`
- Schema and privilege hardening
- Trust, identity, organization, approval, session, authorization, and
  Decision Record structures
- Governance, compliance, assurance, risk, resilience, performance, and
  observability structures
- Security-validation views
- A disposable PostgreSQL test framework
- Writable test logs and summaries
- Behavioral and negative tests as controls are implemented

The Foundation SQL has installed successfully from an empty PostgreSQL 18
database and has passed prior baseline structural and catalog test runs.

That proves only what the executed tests demonstrated. It does not mean every
documented control is already fully enforced. Every Foundation change must be
retested before its branch is described as passing.

## Staged Development Approach

```text
1. Establish the mission, goals, terminology, and architectural boundaries
        ↓
2. Define the normative domain-neutral Platform Foundation
        ↓
3. Build the initial PostgreSQL Foundation structures
        ↓
4. Validate clean installation, catalogs, and baseline privileges
        ↓
5. Add behavioral enforcement and hostile-condition tests
        ↓
6. Establish deployment roles, ownership, and operational security
        ↓
7. Build production Go services against controlled database APIs
        ↓
8. Add Shared Resources and module families
```

Each stage may expose assumptions or weaknesses in an earlier stage. Those
issues are corrected before the project moves forward.

The current SQL is a developing implementation of the architecture, not a
claim that the Platform Foundation is complete.

## Core Principles

### Every Important Decision Must Be Explainable

A material platform decision should retain enough context to answer:

- Who or what requested the action?
- What organization and Platform Service were involved?
- What Governed Purpose and Governed Operation were requested?
- What Protected Resource Target and Governed Scope were involved?
- What Authentication Assertion, session, device, and identity conditions
  existed?
- What policies, Authority Grants, and approvals were evaluated?
- Why was the action allowed, denied, left pending, or escalated?
- Can the historical record be trusted?

### Trust Is Additive

No certificate, password, MFA result, device, session, role, approval,
network location, Authentication Assertion, or Authorization Lease secret
grants unrestricted authority by itself.

A Protected Operation may require multiple independent conditions, including:

- Trusted device and cryptographic context
- Valid identity and account state
- Current organizational eligibility
- Active session
- Appropriate Governed Purpose and Governed Operation
- Exact Protected Resource Target and Governed Scope
- Required independent approvals
- Applicable Authorization Policy Version
- Current context-bound Authorization Lease
- Acceptable security and risk state

### Authentication Is Not Authorization

Authentication establishes who or what is presenting a request.

Authorization determines whether that identity may perform a specific
Governed Operation for a specific Governed Purpose, Protected Resource Target,
organization, Platform Service, Governed Scope, classification, and time.

An Authentication Assertion is an authentication input. Its existence does
not grant authority.

### PostgreSQL Is an Independent Security Boundary

Future Go services will collect and validate Authentication Assertions,
resolve Decision Supporting Records, evaluate applicable policy, and
coordinate workflows.

PostgreSQL will independently verify selected session, Authorization Lease,
exact-context, usage, revocation, and authoritative-time conditions before
completing Protected Operations.

The runtime service must not receive unrestricted ownership or direct
authority over protected data.

### No Unrestricted Platform Account

No ordinary identity, application account, administrator, or accumulated role
set should provide unrestricted platform authority.

High-impact operations may require:

- Separation of duties
- Independent approval
- Short-lived authority
- Exact context binding
- Recorded explanation
- Database-boundary verification

### History Must Not Be Silently Rewritten

Material approvals, decisions, attestations, lifecycle events, Assurance
Artifacts, findings, exceptions, and risk decisions use append-oriented
correction and supersession models.

Complete enforcement also requires:

- Controlled write paths
- Database privileges
- Behavioral and concurrency tests
- Deployment roles
- Protected backups
- Off-host logs
- Trusted recovery procedures

### External Systems Must Remain Replaceable

External Monitoring Systems, Delivery Destinations, Integration Contracts, and
External-System Adapters are replaceable boundaries.

The platform owns its canonical operational records, authorization history,
and delivery intent.

An external product must not become a hidden authorization source or the only
historical source of truth.

### Performance Is a Design Requirement

The platform is intended to remain responsive and supportable on modest
hardware.

Queries, workloads, storage growth, background jobs, integrations, and
delivery processing must be attributable, observable, and bounded.

## Platform Layers

```text
Project Goals and Technology Decisions
        ↓
Domain-Neutral Platform Foundation
        ↓
Platform Services and Shared Resources
        ↓
Module Families
        ↓
External-System Adapters, Integrations, and User Interfaces
```

A lower layer may consume an upper layer.

An upper layer must not acquire a dependency on one specific lower-layer
module, deployment product, monitoring product, or external compliance
framework.

## Platform Foundation Scope

The current Foundation architecture covers:

- Cryptographic and device trust
- Identities and identity lifecycle
- Organizations and Governed Scopes
- Platform Services and configuration
- Service participation and federation
- Attestations and Access Eligibility
- Approval requests and independent actions
- Authority, Governed Purpose, Governed Operation, and Authorization Policy
- Sessions
- Authorization Leases
- PostgreSQL Authentication Assertion and controlled authorization APIs
- Decision and evaluation records
- Data classification and information governance
- Lifecycle history and lineage
- Governed documents and policy versions
- Common controls and compliance profiles
- Control implementations and Assurance Artifacts
- Assessments, findings, remediation, exceptions, and risk
- Threat records and abuse cases
- Resilience, recovery, and continuity
- Workload and resource governance
- Client and deployment performance profiles
- Operational telemetry and health
- Monitoring subscriptions and delivery state
- Transactional external-integration outbox
- Security boundaries and validation inventories

The Foundation does not contain CAD incidents, RMS cases, evidence custody,
fleet maintenance, payroll, student records, utility accounts, permits,
inspections, or other module-owned business records.

## Current Implementation Boundaries

The following remain active work:

- Complete Authentication Assertion verifier-role boundaries
- Scope-aware and target-aware Authorization Lease issuance
- Full approval independence and self-approval enforcement
- Complete Decision Record finalization and immutability controls
- Append-only mutation protection
- Migration-checksum population and enforcement
- Final production ownership and login-role topology
- Least-privileged runtime grants
- Additional behavioral, negative, and concurrency tests
- Production Go services
- External-System Adapters and delivery workers
- Off-host integrity anchoring and protected logging
- Backup protection and restoration validation
- Break-glass access
- Trusted rebuild and compromise recovery
- Shared Resources and module families

These are expected development stages, not hidden claims of completion.

## Migration Ranges

| Range | Purpose |
| --- | --- |
| `000–099` | Platform Foundation |
| `100–199` | Shared Resources and cross-module capabilities |
| `200–899` | Module-owned migrations allocated by an approved module-range decision |
| `900–999` | Deployment and bootstrap |

The authoritative Foundation migration order is maintained in:

[`sql/schema/manifests/foundation.manifest`](sql/schema/manifests/foundation.manifest)

## Repository Layout

```text
.
├── docs/
│   ├── README.md
│   ├── architecture/
│   │   ├── README.md
│   │   ├── postgresql.md
│   │   ├── external-system-independent-observability.md
│   │   └── foundation/
│   ├── compliance-profiles/
│   └── goals/
├── go/
│   └── experiments/
├── sql/
│   ├── schema/
│   │   ├── manifests/
│   │   ├── migrations/
│   │   │   └── foundation/
│   │   └── scripts/
│   └── test-framework/
│       ├── INSTALL.txt
│       ├── Makefile
│       └── sql/
│           ├── schema/scripts/
│           ├── tests/
│           └── test-results/
└── README.md
```

## Documentation

Start with:

- [Platform Documentation](docs/README.md)
- [Architecture Index](docs/architecture/README.md)
- [Platform Foundation Documentation](docs/architecture/foundation/README.md)
- [Foundation Terminology and Domain Neutrality](docs/architecture/foundation/foundation-terminology-and-domain-neutrality.md)
- [Authorization Evaluation Contract](docs/architecture/foundation/authorization-evaluation-contract.md)
- [PostgreSQL Architecture](docs/architecture/postgresql.md)
- [External-System-Independent Observability](docs/architecture/external-system-independent-observability.md)
- [Project Goals](docs/goals/README.md)
- [Compliance Profiles](docs/compliance-profiles/README.md)

## SQL Foundation

The live Foundation SQL is located under:

```text
sql/schema/
├── manifests/foundation.manifest
├── migrations/foundation/
└── scripts/
```

Apply the current Foundation:

```bash
./sql/schema/scripts/apply_foundation.sh
```

Run the human-readable validation report:

```bash
./sql/schema/scripts/validate_foundation.sh
```

Connection settings use normal PostgreSQL environment variables:

```text
PGHOST
PGPORT
PGUSER
PGPASSWORD
PGDATABASE
PGSSLMODE
```

Do not apply the current mutable Foundation baseline to a production database.

A persistent development database created from an older mutable Foundation
should normally be rebuilt from scratch after migration files or registered
migration identifiers change.

## SQL Test Framework

The test framework remains separate from the live migration tree:

```text
sql/test-framework/
```

Run it directly:

```bash
./sql/test-framework/sql/schema/scripts/test_foundation.sh
```

The framework will:

1. Create a uniquely named disposable PostgreSQL database.
2. Apply the live Foundation manifest.
3. Calculate migration-file SHA-256 digests.
4. Install the test-only `sql_test` assertion schema.
5. Run the Foundation SQL tests.
6. Write a complete log and compact summary.
7. Drop a successful database by default.
8. Preserve a failed database by default for investigation.

The newest results are written to:

```text
sql/test-framework/sql/test-results/latest.log
sql/test-framework/sql/test-results/latest-summary.txt
```

See:

- [Test Framework Installation and Operation](sql/test-framework/INSTALL.txt)
- [Foundation SQL Test Framework](sql/test-framework/sql/tests/README.md)

## Go Experiments

The current Go code is historical experimentation created before the
Foundation architecture and database boundaries were established.

It is isolated under:

```text
go/experiments/
```

It is not the production backend.

## Definition of Progress

A migration is not considered complete merely because it executes.

A Foundation change should normally include:

1. A governing architecture requirement
2. A migration or controlled SQL change
3. Clean installation from the authoritative manifest
4. Structural and catalog validation
5. Positive and negative behavioral tests
6. Concurrency testing when state can be consumed or changed simultaneously
7. Updated documentation
8. Deployment and operational controls when the change crosses the database
   boundary

## Production Readiness

This repository is not production-ready.

Before production use, the platform must establish and validate:

- Host compromise containment
- Trusted ownership and runtime roles
- Secret and key management
- Integrity verification
- Off-host logging
- Backup encryption and protection
- Restore testing
- Break-glass access
- Trusted rebuild and compromise recovery
- Operational monitoring
- Incident response procedures
- Complete authorization behavior
- Domain-specific legal, policy, and compliance requirements

## Final Goal

The repository exists to create a trusted operational foundation where every
important decision can be understood, verified, and defended.

Public safety is the first implementation target.

The Foundation must be strong and neutral enough that municipalities, schools,
and other organizations can build unrelated operational modules upon it
without recreating the security boundary each time.
