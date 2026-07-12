# Iron Signal Platform

> An Iron Signal Systems project
>
> Built on purpose. Backed by discipline. Engineered to endure.
>
> **Development status: Pre-alpha, domain-neutral Platform Foundation**
>
> This repository began with public safety as its first operational focus.
> Current development is concentrated on the shared Platform Foundation that
> future public-safety, municipal, school, and other institutional modules may
> use. The SQL is active work being completed in deliberate stages. This
> repository is not ready for production use.

## Project Mission

Every important decision should have an explanation.

Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.

The ultimate measure of success is not the number of features implemented, but whether the people who depend on the system can trust it when it matters most.

## Platform Scope and Long-Term Direction

Public safety remains the planned first module family, but it does not define
the limits of the Platform Foundation.

The Platform Foundation is domain-neutral. It provides shared capabilities for:

- Trust and cryptographic context
- Identity and identity lifecycle
- Authentication Assertions
- Sessions
- Authorization
- Independent approvals
- Decision Records
- Governance and compliance
- Resilience and continuity
- Observability and operational telemetry
- External-system integration
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

The Foundation contains only broadly reusable concepts, shared security
boundaries, and neutral extension points.

A legal or geographic authority boundary, for example, is represented by a
Governed Scope whose module-defined type may be `JURISDICTION`. Jurisdiction
is not imposed as a universal Foundation concept.

The long-term objective is to let small municipalities, schools, and similar
organizations add or replace operational modules without rebuilding the
security and governance foundation for every application.

## Initial Operational Direction

Public safety is the initial module family because it creates demanding
requirements for identity, authorization, availability, auditability,
historical integrity, and explainable decisions.

Possible public-safety modules include:

- Computer Aided Dispatch
- Records Management
- Evidence and Property
- Personnel Operations
- Fleet Management
- Fire and EMS Operations
- Additional public-safety capabilities

Computer Aided Dispatch is planned as the first operational module, but CAD
does not define the Platform Foundation.

## Current Development Stage

Development is presently focused on the Platform Foundation.

The accepted initial Foundation baseline includes:

- Normative Foundation architecture documentation
- A domain-neutral terminology model
- Manifest-driven PostgreSQL migrations `000–099`
- 31 ordered and registered Foundation migrations
- Clean installation into an empty PostgreSQL 18 database
- Schema and privilege hardening
- Trust, identity, organization, approval, session, authorization, and
  Decision Record structures
- Authentication Assertion verification, revocation, exact-context
  consumption, and replay protection
- Authorization Lease secret verification and complete context verification
- Governed Operation identity binding
- Governance, compliance, assurance, risk, resilience, performance, and
  observability structures
- Security-validation views
- A disposable PostgreSQL test framework
- Writable test logs and summaries
- Positive and negative database behavior tests

The accepted Phase 0 SQL test baseline is:

```text
31 manifest migrations
31 registered migrations
65 PASS
0 FAIL
3 understood WARN
```

The accepted Phase 1 Authentication Assertion baseline is:

```text
31 manifest migrations
31 registered migrations
10 sequential test files
1 concurrency test file
135 PASS
0 FAIL
3 understood WARN
```

Phase 1 proved controlled local verification, exact-context single-use
consumption, terminal lifecycle behavior, and a real two-connection race in
which exactly one consumer succeeded. The accepted boundary is tagged as
`phase-1-authentication-assertion-complete-v1`.

Phase 2 has started with the normative
[Session Establishment, Step-Up, and Lifecycle Model](docs/architecture/foundation/session-establishment-step-up-and-lifecycle-model.md).
It will implement atomic session establishment, atomic step-up completion,
controlled activity and lifecycle transitions, and the required concurrency
proofs without weakening Phase 1.

These results prove only the properties covered by the accepted tests. They do
not mean every documented Foundation control is already fully enforced.

## Staged Development Approach

```text
1. Establish the mission, goals, and architectural boundaries
        ↓
2. Define the normative, domain-neutral Platform Foundation
        ↓
3. Build the initial PostgreSQL Foundation structures
        ↓
4. Validate clean installation, catalogs, and baseline privileges
        ↓
5. Implement behavioral enforcement and hostile-condition tests
        ↓
6. Establish deployment roles, ownership, and operational security
        ↓
7. Build production Go services against controlled database APIs
        ↓
8. Add Shared Resources and operational module families
```

Each stage may expose assumptions or weaknesses in an earlier stage.

Those issues are corrected before the project moves forward.

The current SQL should therefore be read as a developing implementation of
the architecture, not as a claim that the Platform Foundation is complete.

## Core Principles

### Every Important Decision Must Be Explainable

A material platform decision should retain enough context to answer:

- Who or what requested the action?
- What organization and Platform Service were involved?
- What Governed Purpose and Governed Operation were requested?
- What Protected Resource Target and Governed Scope were involved?
- What identity, device, session, and Authentication Assertion conditions
  existed?
- What policies, Authority Grants, and approvals were evaluated?
- Why was the action allowed, denied, left pending, or escalated?
- Can the historical record be trusted?

### Trust Is Additive

No certificate, password, MFA result, device, session, role, approval, network
location, or lease secret grants unrestricted authority by itself.

A Protected Operation may require:

- Trusted device and cryptographic context
- Valid identity and account state
- Current organizational Access Eligibility
- Active session
- Appropriate Governed Purpose and Governed Operation
- Exact Protected Resource Target and Governed Scope
- Required independent approvals
- Applicable Authorization Policy Version
- Current, context-bound Authorization Lease
- Acceptable security and risk state

### Authentication Is Not Authorization

Authentication establishes who or what is presenting a request.

Authorization determines whether that identity may perform a specific
Governed Operation, for a specific Governed Purpose, against a specific
Protected Resource Target, within the applicable organization, Platform
Service, Governed Scope, Data Classification, policy, and time context.

### PostgreSQL Is an Independent Security Boundary

Future Go services will assemble explicit authorization inputs and Decision
Supporting Records, invoke controlled workflows, and coordinate external
interactions.

PostgreSQL will independently verify the minimum database-boundary conditions
required before completing a Protected Operation.

A runtime service must not receive unrestricted ownership or direct authority
over protected data.

### No Unrestricted Platform Account

No ordinary identity, application account, administrator, or accumulated role
set should provide unrestricted platform authority.

High-impact operations may require separation of duties, independent approval,
short-lived authority, exact context binding, recorded justification, and a
durable Decision Record.

### History Must Not Be Silently Rewritten

Material approvals, decisions, attestations, lifecycle events, Assurance
Artifacts, findings, exceptions, and risk decisions use append-oriented
correction and supersession models.

Complete enforcement also requires database privileges, controlled write
paths, immutability controls, behavioral and concurrency tests, deployment
roles, protected backups, off-host logs, and trusted recovery procedures.

### External Systems Must Remain Replaceable

External Monitoring Systems, Delivery Destinations, Integration Contracts, and
External-System Adapters must remain replaceable.

The platform owns its canonical operational records, Decision Records,
telemetry, outbox records, and delivery intent.

An external product must not become a hidden authorization source, historical
source of truth, or mandatory Foundation dependency unless an explicit
architecture decision establishes that boundary.

### Performance Is a Design Requirement

The platform is intended to remain responsive and supportable on modest
hardware.

Queries, workloads, storage growth, background jobs, integrations, and
delivery to external systems must be attributable, observable, and bounded.

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

Examples of module families include public safety, municipal administration,
education, finance, public works, utilities, permitting, and human resources.

A lower layer may consume an upper layer.

An upper layer must not acquire a dependency on one specific lower-layer
module.

The Platform Foundation must not depend on a specific operational module,
deployment vendor, monitoring product, or external compliance framework.

## Platform Foundation Scope

The current Foundation architecture covers:

- Cryptographic and device trust
- Identities and identity lifecycle
- Trust Provider identity mappings
- Organizations and Governed Scopes
- Platform Services and configuration
- Service participation and federation
- Attestations and Access Eligibility
- Approval Requests and independent decisions
- Authority Definitions and Authority Grants
- Governed Purposes and Governed Operations
- Authorization Policies and policy versions
- Sessions and session events
- Authorization Leases and lease-use events
- Authentication Assertions
- PostgreSQL controlled authorization APIs
- Decision Records and evaluation records
- Decision Supporting Records
- Data Classification and information governance
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
- Transactional integration outbox
- Security boundaries and validation inventories

The Foundation does not contain CAD incidents, RMS cases, evidence custody,
fleet maintenance, payroll, Fire and EMS clinical workflows, student records,
utility accounts, permits, or other module-specific business records.

## Current Implementation Boundaries

Implemented behavior now includes:

- Authentication Assertion lifecycle constraints
- Controlled Authentication Assertion verification
- Exact Authentication Assertion context matching
- Atomic Authentication Assertion consumption
- Replay denial
- Authentication Assertion revocation with history preservation
- Authentication Assertion concurrent single-use proof
- Authorization Lease secret hashing
- Secret-only lease verification
- Complete Authorization Lease context verification
- Atomic lease-use consumption
- Authorization Lease revocation
- Governed Operation key-to-definition binding
- Decision Record finalization checks against recorded required-stage failures
- Manifest-driven clean installation
- Structural, catalog, privilege, and selected behavioral tests

The following remain active Foundation work:

- Trust-Provider-specific verifier-role and credential boundary enforcement
- Atomic session establishment from a verified Authentication Assertion
- Complete session lifecycle APIs and concurrency behavior
- Full approval independence and self-approval enforcement
- Deterministic Authorization Policy selection and stage resolution
- Controlled Authorization Lease issuance and renewal
- Cross-record context consistency during lease issuance
- Complete Decision Record required-stage completeness
- Decision Record hashing and integrity anchoring
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
- Shared Resources and operational modules

These are expected development stages, not hidden claims of completion.

## Migration Ranges

| Range | Purpose |
|---|---|
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
│   └── schema/
│       ├── manifests/
│       ├── migrations/
│       │   └── foundation/
│       └── scripts/
├── test-framework/
│   ├── INSTALL.txt
│   ├── Makefile
│   └── sql/
│       ├── schema/
│       │   └── scripts/
│       ├── tests/
│       └── test-results/
└── README.md
```

## Documentation

Start with:

- [Platform Documentation](docs/README.md)
- [Architecture Index](docs/architecture/README.md)
- [Platform Foundation Documentation](docs/architecture/foundation/README.md)
- [Foundation Terminology and Domain Neutrality](docs/architecture/foundation/foundation-terminology-and-domain-neutrality.md)
- [Authorization Evaluation Contract](docs/architecture/foundation/authorization-evaluation-contract.md)
- [Authentication Assertion Verification and Consumption Model](docs/architecture/foundation/authentication-assertion-verification-and-consumption-model.md)
- [Phase 1 Authentication Assertion Acceptance](docs/architecture/foundation/phase-1-authentication-assertion-acceptance.md)
- [Session Establishment, Step-Up, and Lifecycle Model](docs/architecture/foundation/session-establishment-step-up-and-lifecycle-model.md)
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

Create a fresh development database:

```bash
createdb dev_testing
```

Apply the current Foundation:

```bash
./sql/schema/scripts/apply_foundation.sh dev_testing
```

Run the human-readable validation report:

```bash
./sql/schema/scripts/validate_foundation.sh dev_testing
```

Connection settings use normal PostgreSQL environment variables:

```text
PGHOST
PGPORT
PGUSER
PGPASSWORD
PGSSLMODE
```

Do not apply the current mutable Foundation to a production database.

During pre-stable development, rebuild disposable and development databases
from an empty database when migration names or previously applied migration
contents change.

## SQL Test Framework

The test framework intentionally remains separate from the live migration
tree:

```text
test-framework/
```

Run it with:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

The framework will:

1. Perform dependency and PostgreSQL preflight checks.
2. Create a uniquely named disposable PostgreSQL database.
3. Apply the live Foundation manifest.
4. Calculate migration-file SHA-256 digests.
5. Install the test-only `sql_test` assertion schema.
6. Run the Foundation SQL test manifest.
7. Write a complete log and compact summary.
8. Drop a successful database by default.
9. Preserve a failed database by default for investigation.

The newest results are written to:

```text
test-framework/sql/test-results/latest.log
test-framework/sql/test-results/latest-summary.txt
```

See:

- [Test Framework Installation and Operation](test-framework/INSTALL.txt)
- [Foundation SQL Test Framework](test-framework/sql/tests/README.md)

## Go Experiments

The current Go code is historical experimentation created before the
Foundation architecture and database boundaries were established.

It is intentionally isolated under:

```text
go/experiments/
```

It is not the production backend and will not be extended as though it were
current platform code.

Production Go design will begin only after the controlling Foundation
contracts and database boundaries are sufficiently complete.

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

The platform exists to provide a trusted operational foundation where every
important decision can be understood, verified, and defended.

Public safety is the first planned module family and one of the most demanding
tests of that Foundation.

The Foundation succeeds only when municipalities, schools, and similar
organizations can rely on it without surrendering security, explainability,
historical integrity, operational control, or the ability to replace external
systems.

