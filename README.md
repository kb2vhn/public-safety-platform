# Public Safety Platform

> **Development status: Pre-alpha Platform Foundation**
>
> The project is currently focused on defining, implementing, and validating the shared Platform Foundation that future public-safety modules will depend on. The SQL is active work being completed in deliberate stages. This repository is not ready for production use.

## Project Mission

Every important decision should have an explanation.

Build software that is secure, understandable, observable, and dependable enough that I would trust my own local community to rely on it during an emergency.

The ultimate measure of success is not the number of features implemented, but whether the people who depend on the system can trust it when it matters most.

## Project Direction

The Public Safety Platform is intended to become a modular operational platform for capabilities such as:

* Computer Aided Dispatch
* Records Management
* Evidence and Property
* Personnel Operations
* Fleet Management
* Fire and EMS Operations
* Future public-safety services

Computer Aided Dispatch is planned as the first operational module, but CAD does not define the platform.

Shared trust, identity, authorization, approvals, decision recording, governance, compliance, resilience, observability, and resource controls belong in a common Platform Foundation so that each operational module does not recreate them independently.

## Current Development Stage

Development is presently focused on the Platform Foundation.

The current work includes:

* Normative Foundation architecture documentation
* Manifest-driven PostgreSQL migrations `000–099`
* Schema and privilege hardening
* Trust, identity, organization, approval, session, authorization, and decision-record structures
* Governance, compliance, assurance, risk, resilience, performance, and observability structures
* Security-validation views
* A disposable PostgreSQL test framework
* Writable test logs and summaries
* Behavioral and negative tests as database controls are implemented

The Foundation SQL has successfully installed from an empty PostgreSQL 18 database and passed the current baseline structural and catalog test suite.

That proves the current migrations are structurally coherent. It does not mean every documented control is already fully enforced.

## Staged Development Approach

The platform is being developed in deliberate stages:

```text
1. Establish the mission, goals, and architectural boundaries
                         ↓
2. Define the normative Platform Foundation
                         ↓
3. Build the initial PostgreSQL Foundation structures
                         ↓
4. Validate clean installation, catalogs, and baseline privileges
                         ↓
5. Add behavioral enforcement and hostile-condition tests
                         ↓
6. Establish deployment roles, ownership, and operational security
                         ↓
7. Build the production Go services against controlled database APIs
                         ↓
8. Add Operational Resources and public-safety modules
```

Each stage may expose assumptions or weaknesses in an earlier stage. Those issues are corrected before the project moves forward.

The current SQL should therefore be read as a developing implementation of the architecture, not as a claim that the Platform Foundation is complete.

## Core Principles

### Every Important Decision Must Be Explainable

A material platform decision should retain enough context to answer:

* Who or what requested the action?
* What organization and service were involved?
* What purpose and operation were requested?
* What trust, session, device, and identity conditions existed?
* What policies and approvals were evaluated?
* Why was the action allowed or denied?
* Can the historical record be trusted?

### Trust Is Additive

No certificate, password, MFA result, device, session, role, approval, or network location grants unrestricted authority by itself.

A protected action may require multiple independent proofs, including:

* Trusted device and cryptographic context
* Valid identity and account state
* Current organizational eligibility
* Active session
* Appropriate purpose and operation
* Required independent approvals
* Applicable authorization policy
* Current, scope-bound Authorization Lease
* Acceptable security and risk state

### Authentication Is Not Authorization

Authentication establishes who or what is presenting a request.

Authorization determines whether that identity may perform a specific operation, for a specific purpose, within a specific organization, service, jurisdiction, classification, and time period.

### PostgreSQL Is an Independent Security Boundary

The future Go services will gather evidence, evaluate policy, and coordinate workflows.

PostgreSQL will independently verify selected trust and authorization requirements before completing protected operations.

The runtime service must not receive unrestricted ownership or direct authority over protected data.

### No Unrestricted Platform Account

No ordinary identity, application account, administrator, or accumulated role set should provide unrestricted platform authority.

High-impact operations may require separation of duties, independent approval, short-lived authority, and recorded justification.

### History Must Not Be Silently Rewritten

Material approvals, decisions, attestations, lifecycle events, assurance artifacts, findings, exceptions, and risk decisions use append-oriented correction and supersession models.

Complete enforcement requires database privileges, controlled write paths, tests, deployment roles, protected backups, off-host logs, and trusted recovery procedures.

### Providers Must Remain Replaceable

Monitoring, logging, metrics, tracing, alerting, SIEM, and integration products are adapters.

The platform owns its canonical operational records and delivery intent. External providers must not become hidden authorization or historical sources of truth.

### Performance Is a Design Requirement

The platform is intended to remain responsive and supportable on modest hardware.

Queries, workloads, storage growth, background jobs, integrations, and provider delivery must be attributable, observable, and bounded.

## Platform Layers

```text
Project Goals and Technology Decisions
                  ↓
          Platform Foundation
                  ↓
        Operational Resources
                  ↓
 CAD, RMS, Evidence, Personnel, Fleet, Fire, EMS
                  ↓
 Provider Adapters, Integrations, and User Interfaces
```

A lower layer may consume an upper layer.

The Platform Foundation must not depend on a specific operational module, deployment provider, monitoring product, or external compliance framework.

## Platform Foundation Scope

The current Foundation architecture covers:

* Cryptographic and device trust
* Identities and identity lifecycle
* Organizations and jurisdictions
* Platform services and configuration
* Service participation and federation
* Attestations and access eligibility
* Approval requests and independent decisions
* Authority, purpose, and authorization policy
* Sessions
* Authorization Leases
* PostgreSQL trust and controlled authorization APIs
* Decision and evaluation records
* Data classification and information governance
* Lifecycle history and lineage
* Governed documents and policy versions
* Common controls and compliance profiles
* Control implementations and assurance artifacts
* Assessments, findings, remediation, exceptions, and risk
* Threat records and abuse cases
* Resilience, recovery, and continuity
* Workload and resource governance
* Client and deployment performance profiles
* Operational telemetry and health
* Monitoring subscriptions and provider delivery state
* Transactional integration outbox
* Security boundaries and validation inventories

The Foundation is domain-neutral.

It does not contain CAD incidents, RMS cases, evidence custody, fleet maintenance, payroll, Fire and EMS clinical workflow, or other module-specific business records.

## Current Implementation Boundaries

The current SQL provides an initial structural implementation and selected database controls.

The following remain active work:

* Complete Trust Assertion context binding
* Scope-aware Authorization Lease verification
* Full approval independence and self-approval enforcement
* Complete Decision Record consistency and integrity controls
* Append-only mutation protection
* Migration-checksum population and enforcement
* Final production ownership and login-role topology
* Least-privileged runtime grants
* Behavioral, negative, and concurrency tests
* Production Go services
* Provider adapters and workers
* Off-host integrity anchoring and protected logging
* Backup protection and restoration validation
* Break-glass access
* Trusted rebuild and compromise recovery
* Operational Resources and public-safety modules

These are expected development stages, not hidden claims of completion.

## Migration Ranges

| Range     | Purpose                  |
| --------- | ------------------------ |
| `000–099` | Platform Foundation      |
| `100–199` | Operational Resources    |
| `200–299` | CAD                      |
| `300–399` | RMS                      |
| `400–499` | Evidence and Property    |
| `500–599` | Personnel extensions     |
| `600–699` | Fleet extensions         |
| `700–799` | Fire and EMS             |
| `800–899` | Future modules           |
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
│   │   ├── provider-neutral-observability.md
│   │   └── foundation/
│   ├── compliance-profiles/
│   └── goals/
├── go/
│   └── experiments/
├── sql/
│   ├── past_scripts/
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

* [Platform Documentation](docs/README.md)
* [Architecture Index](docs/architecture/README.md)
* [Platform Foundation Documentation](docs/architecture/foundation/README.md)
* [PostgreSQL Architecture](docs/architecture/postgresql.md)
* [Provider-Neutral Observability](docs/architecture/provider-neutral-observability.md)
* [Project Goals](docs/goals/README.md)
* [Compliance Profiles](docs/compliance-profiles/README.md)

## SQL Foundation

The live Foundation SQL is located under:

```text
sql/schema/
├── manifests/foundation.manifest
├── migrations/foundation/
└── scripts/
```

Apply the current Foundation with:

```bash
./sql/schema/scripts/apply_foundation.sh
```

Run the human-readable validation report with:

```bash
./sql/schema/scripts/validate_foundation.sh
```

Connection settings use normal PostgreSQL environment variables such as:

```text
PGHOST
PGPORT
PGUSER
PGPASSWORD
PGDATABASE
PGSSLMODE
```

Do not apply the current Foundation to a production database.

## SQL Test Framework

The test framework intentionally remains separate from the live migration tree:

```text
sql/test-framework/
```

Run it with:

```bash
cd sql/test-framework
make test-sql
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

* [Test Framework Installation and Operation](sql/test-framework/INSTALL.txt)
* [Foundation SQL Test Framework](sql/test-framework/sql/tests/README.md)

## Go Experiments

The current Go code is historical experimentation created before the Foundation architecture and database boundaries were established.

It is intentionally isolated under:

```text
go/experiments/
```

It is not the production backend and will not be extended as though it were current platform code.

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
8. Deployment and operational controls when the change crosses the database boundary

## Production Readiness

This repository is not production-ready.

Before production use, the platform must establish and validate:

* Host compromise containment
* Trusted ownership and runtime roles
* Secret and key management
* Integrity verification
* Off-host logging
* Backup encryption and protection
* Restore testing
* Break-glass access
* Trusted rebuild and compromise recovery
* Operational monitoring
* Incident response procedures
* Complete authorization behavior
* Domain-specific legal, policy, and compliance requirements

## Final Goal

The Public Safety Platform exists to create a trusted operational foundation where every important decision can be understood, verified, and defended.

A public-safety system should not merely function.

It should be worthy of trust.

