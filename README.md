# Iron Signal Platform

> An Iron Signal Systems project
>
> **Built on purpose. Backed by discipline. Engineered to endure.**
>
> **Development status: Pre-alpha, domain-neutral Platform Foundation**
>
> This repository began with public safety as its first operational focus.
> Current development is concentrated on the shared Platform Foundation that
> future public-safety, municipal, school, and other institutional modules may
> use. The SQL is active work being completed in deliberate stages. This
> repository is not ready for production use.

Canonical repository:

```text
https://github.com/Iron-Signal-Systems/iron-signal-platform
```

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

The current Foundation includes:

- Normative, domain-neutral architecture documentation
- Manifest-driven PostgreSQL migrations in the `000–099` range
- Clean installation into an empty PostgreSQL 18 database
- Schema and privilege hardening
- Trust, identity, organization, approval, session, authorization, and
  Decision Record structures
- Controlled Authentication Assertion lifecycle and consumption
- Controlled session establishment, step-up, activity, and lifecycle behavior
- Deterministic Authorization Policy selection
- Controlled Decision Record finalization
- Controlled Authorization Lease issuance, verification, use, expiration,
  and revocation
- Independent-connection concurrency proofs
- Approval-independence and separation-of-duties structures
- Resource telemetry and performance-regression observation
- Governance, compliance, assurance, risk, resilience, performance, and
  observability structures
- Security-validation views
- A disposable PostgreSQL test framework
- Writable correctness logs, summaries, and resource-observation reports
- Positive, negative, and concurrency behavior tests

### Accepted Phase 0 Baseline

```text
31 manifest migrations
31 registered migrations
65 PASS
0 FAIL
3 understood WARN
```

### Accepted Phase 1 — Authentication Assertions

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
which exactly one consumer succeeded.

Accepted tag:

```text
phase-1-authentication-assertion-complete-v1
```

### Accepted Phase 2 — Session Control

```text
32 manifest migrations
32 registered migrations
12 sequential test files
4 concurrency test files
213 PASS
0 FAIL
3 understood WARN
```

Phase 2 proved atomic session establishment, controlled step-up, activity and
lifecycle transitions, and independent-connection race behavior without
weakening Phase 1.

Accepted tag:

```text
phase-2-session-control-complete-v1
```

### Accepted Phase 3 — Authorization Decision and Controlled Lease Issuance

```text
33 manifest migrations
33 registered migrations
16 sequential test files
9 concurrency test files
408 PASS
0 FAIL
3 understood WARN
```

Phase 3 proved deterministic policy selection, required-stage closure,
finalization-once Decision Records, controlled Authorization Lease issuance
and exact-context use, fail-closed current-state revalidation, and
independent-connection finalization, issuance, consumption, expiration, and
revocation races.

Accepted tag:

```text
phase-3-authorization-control-complete-v1
```

Formal acceptance record:

- [Phase 3 Authorization Decision and Controlled Lease Acceptance](docs/architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)

### Accepted Phase 4 — Approval Independence and Separation of Duties

Phase 4 is formally accepted for the scope defined by the normative approval
independence and separation-of-duties contract.

Accepted tag:

```text
phase-4-approval-independence-and-separation-of-duties-complete-v1
```

Formal acceptance record:

- [Phase 4 Approval Independence and Separation of Duties Acceptance](docs/architecture/foundation/phase-4-approval-independence-and-separation-of-duties-acceptance.md)

Accepted boundary:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
16 concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
159 phase-gate PASS checks
0 phase-gate FAIL checks
```

The accepted Phase 4 boundary includes controlled Approval Action recording,
requester and directly affected identity independence, effective-actor
uniqueness, organization and Authority Grant origin independence, explicit
reciprocal-request protection, delegated-grant lineage, incompatible-authority
and prohibited-duty enforcement, current stage satisfaction, finalization-once
Approval Requests, Decision Record stage linkage, approval continuity, and
independent-connection concurrency proofs.

The seven Phase 4 concurrency files prove duplicate-actor serialization,
finalized stage-evaluation uniqueness, Approval Request finalization,
last-approval and withdrawal races, Authority Grant revocation exclusion, and
reciprocal approval protection across explicitly linked requests.

These results prove only the properties covered by the accepted tests. They do
not declare the complete Platform Foundation, Go services, deployment
environment, operational modules, or production operating model ready for
production use.

### Active Phase 5 — Production Database Security Boundary

Phase 4 approval independence and separation of duties is formally accepted at
`phase-4-approval-independence-and-separation-of-duties-complete-v1`.

Phase 5 Step 1 freezes the production database role, ownership, migration, and runtime-privilege contract.

The Step 1 boundary defines separate non-login owners, controlled migration
authority, service-specific login identities, capability-based runtime roles,
read-only investigation, audit review, validation access, creator-specific
default privileges, and disabled-at-rest break-glass access.

Step 1 changes no accepted Foundation SQL or executable tests. The complete
Phase 4 regression remains:

```text
34 manifest migrations
34 registered migrations
21 sequential test files
16 concurrency test files
734 PASS
0 FAIL
3 understood WARN
Correctness result: PASS
Resource observation: RECORDED
Performance thresholds: NOT_EVALUATED
```

Governing contract:

- [Production Database Role, Ownership, and Runtime Privilege Model](docs/architecture/foundation/production-database-role-ownership-and-runtime-privilege-model.md)

Active gate:

```bash
./tools/validation/phase-gates/validate_phase5_step1.sh
```

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

### Approval Is Not a Raw Row Count

An approval stage is not satisfied merely because a table contains enough
rows labeled `APPROVE`.

Approval satisfaction must consider the current policy stage, distinct
effective actors, actor eligibility, independence, exact Authority Grant
context, incompatible authority, prohibited duties, withdrawals, corrections,
supersession, expiration, and other governed conditions.

### History Must Not Be Silently Rewritten

Material Approval Action Records, decisions, attestations, lifecycle events,
Assurance Artifacts, findings, exceptions, and risk decisions use
append-oriented correction and supersession models where their governing
contract requires it.

The term `evidence` is not used as a substitute for these distinct record
types. Supporting Records, Assurance Artifacts, legal evidence, operational
evidence, and module-owned evidence records may have different lifecycle and
retention requirements.

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

Correctness results and resource observations remain separate. Resource
telemetry begins as observation-only data. Performance thresholds are not
promoted into pass/fail gates until representative same-environment runs
establish defensible budgets.

Ordinary clean-install Foundation migrations use a separate execution-safety
contract: a five-second lock-wait limit, a one-minute per-statement limit, and
a one-minute idle-in-transaction limit. Any individual migration statement
observed above ten seconds requires investigation. The limits expose abnormal
behavior; they are not the expected duration and do not activate a general
performance-regression failure threshold.

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
- Approval Policies, Approval Requests, and Approval Action Records
- Approval independence and separation-of-duties structure
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
- Resource telemetry and performance-regression observation
- Operational telemetry and health
- Monitoring subscriptions and delivery state
- Transactional integration outbox
- Security boundaries and validation inventories

The Foundation does not contain CAD incidents, RMS cases, evidence custody,
fleet maintenance, payroll, Fire and EMS clinical workflows, student records,
utility accounts, permits, or other module-specific business records.

## Current Implementation Boundaries

### Accepted Behavior

Accepted behavior now includes:

- Authentication Assertion lifecycle constraints
- Controlled Authentication Assertion verification
- Exact Authentication Assertion context matching
- Atomic Authentication Assertion consumption
- Replay denial
- Authentication Assertion revocation with history preservation
- Authentication Assertion concurrent single-use proof
- Atomic session establishment from a verified Authentication Assertion
- Controlled session step-up, activity, locking, termination, and expiration
- Session lifecycle concurrency proofs
- Deterministic Authorization Policy Version selection
- Required-stage closure and fail-closed Decision Record finalization
- Controlled Authorization Lease issuance and renewal binding
- Authorization Lease secret hashing
- Exact-context Authorization Lease verification and use
- Reusable, single-use, and limited-use accounting
- Authorization Lease expiration and revocation
- Failed-use denial without successful-use side effects
- Authorization finalization, issuance, consumption, and terminal-transition
  concurrency proofs
- Approval-independence and separation-of-duties structures
- Approval-stage Authority Definition binding
- Effective-actor, session, Authority Grant, and duty-link structures
- Resource telemetry text and JSON observations
- Manifest-driven clean installation
- Structural, catalog, privilege, behavioral, negative, and concurrency tests

### Accepted Phase 4 Boundary

Phase 4 approval independence and separation of duties is formally accepted.
The tagged implementation provides:

- Exact Approval Request, policy-stage, actor, organization, session, and
  Authority Grant binding
- Requester, directly affected identity, duplicate effective actor, distinct
  organization, Authority Grant origin, and reciprocal-chain independence
- Delegated Authority Grant lineage and bounded delegation
- `JOINT_EXERCISE`, `CONCURRENT_HOLDING`, and `CHAIN_PARTICIPATION`
  incompatible-authority enforcement
- Immutable `APPROVE` duty recording and prohibited-duty evaluation
- Current Approval Action derivation, stage satisfaction, blocking denial, and
  finalization-once Approval Requests
- Exact Decision Record stage linkage and approval-backed lease continuity
- Independent-connection concurrency proofs without one global approval lock

Backend services, communications, GIS and mapping, operational workstations,
user interfaces, and operational modules remain downstream consumers of
governed Foundation decisions. No module-specific record or workflow is part of
the accepted Phase 4 Foundation boundary.

### Remaining Foundation Work

The following remain active Foundation work:

- Decision Record cryptographic integrity anchoring
- Stronger append-only mutation protection where required
- Migration-checksum population and enforcement
- Trust-Provider-specific verifier-role and credential boundary enforcement
- Final production ownership and login-role topology
- Least-privileged runtime grants
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
│   │   ├── foundation/
│   │   └── user-interface/
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
├── tools/
│   └── validation/
│       └── phase-gates/
└── README.md
```

## Documentation

Start with:

- [Platform Documentation](docs/README.md)
- [Architecture Index](docs/architecture/README.md)
- [Platform Foundation Documentation](docs/architecture/foundation/README.md)
- [Foundation Terminology and Domain Neutrality](docs/architecture/foundation/foundation-terminology-and-domain-neutrality.md)
- [Authorization Evaluation Contract](docs/architecture/foundation/authorization-evaluation-contract.md)
- [Approval Framework](docs/architecture/foundation/approval-framework.md)
- [Approval Independence and Separation of Duties](docs/architecture/foundation/approval-independence-and-separation-of-duties-model.md)
- [Resource Telemetry and Performance-Regression Testing](docs/architecture/foundation/resource-telemetry-and-performance-regression-testing-model.md)
- [Foundation Migration Timeout and Execution Performance Standard](docs/architecture/foundation/foundation-migration-timeout-and-execution-performance-standard.md)
- [Authentication Assertion Verification and Consumption Model](docs/architecture/foundation/authentication-assertion-verification-and-consumption-model.md)
- [Session Establishment, Step-Up, and Lifecycle Model](docs/architecture/foundation/session-establishment-step-up-and-lifecycle-model.md)
- [Authorization Decision and Lease Issuance Model](docs/architecture/foundation/authorization-decision-and-lease-issuance-model.md)
- [Phase 3 Authorization Acceptance](docs/architecture/foundation/phase-3-authorization-decision-and-controlled-lease-acceptance.md)
- [Phase 4 Approval Independence and Separation of Duties Acceptance](docs/architecture/foundation/phase-4-approval-independence-and-separation-of-duties-acceptance.md)
- [PostgreSQL Architecture](docs/architecture/postgresql.md)
- [External-System-Independent Observability](docs/architecture/external-system-independent-observability.md)
- [User-Interface Architecture](modules/CAD/docs/architecture/user-interface/README.md)
- [Project Goals](docs/goals/README.md)
- [Compliance Profiles](docs/compliance-profiles/README.md)
- [Validation Tools](tools/validation/README.md)

## SQL Foundation

The live Foundation SQL is located under:

```text
sql/schema/
├── manifests/foundation.manifest
├── migrations/foundation/
└── scripts/
```

Every ordinary manifest migration establishes this clean-install execution
contract immediately after `BEGIN;`:

```sql
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '1min';
SET LOCAL idle_in_transaction_session_timeout = '1min';
```

Validate the static contract with:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

See [Foundation Migration Timeout and Execution Performance Standard](docs/architecture/foundation/foundation-migration-timeout-and-execution-performance-standard.md).

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

Run correctness tests directly with:

```bash
./test-framework/sql/schema/scripts/test_foundation.sh
```

Run correctness tests with resource observation using:

```bash
./test-framework/sql/schema/scripts/test_foundation_with_resources.sh
```

The correctness framework will:

1. Perform dependency and PostgreSQL preflight checks.
2. Create a uniquely named disposable PostgreSQL database.
3. Apply the live Foundation manifest.
4. Calculate migration-file SHA-256 digests.
5. Install the test-only `sql_test` assertion schema.
6. Run the sequential Foundation SQL test manifest.
7. Run independent-connection concurrency tests.
8. Write a complete log and compact summary.
9. Drop a successful database by default.
10. Preserve a failed database by default for investigation.

The resource-aware wrapper retains a successful disposable database long
enough to record:

- Correctness-runner and phase durations
- User and system CPU
- Effective CPU utilization
- Peak resident memory
- Page faults and filesystem counters
- Context switches
- PostgreSQL transactions, rollbacks, block activity, temporary files, and
  deadlocks
- Observed WAL change
- Disposable-database size
- Host, kernel, CPU, memory, and PostgreSQL fingerprint

Correctness and resource outcomes remain separate:

```text
Correctness result: PASS or FAIL
Resource observation: RECORDED or NOT_RECORDED
Performance thresholds: NOT_EVALUATED
```

The newest results are written to:

```text
test-framework/sql/test-results/latest.log
test-framework/sql/test-results/latest-summary.txt
test-framework/sql/test-results/latest-resources.txt
test-framework/sql/test-results/latest-resources.json
```

See:

- [Test Framework Installation and Operation](test-framework/INSTALL.txt)
- [Foundation SQL Test Framework](test-framework/sql/tests/README.md)

## Current Phase Gate

Phase 4 is formally accepted. Revalidate the accepted boundary from the
repository root with:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh
```

Static repository, tag, tree-integrity, and documentation validation only:

```bash
./tools/validation/phase-gates/validate_phase4_step8.sh --static-only
```

The gate validates the annotated Phase 4 tag, the accepted implementation
commit, unchanged SQL and executable test trees, 34 Foundation migrations,
21 sequential tests, 16 concurrency tests, the 734 PASS result, the three
understood warnings, synchronized acceptance documentation, and
observation-only resource telemetry.

Historical phase gates remain available and validate their own checkpoint
trees. The Step 7 gate is the implementation gate for the tagged Phase 4 tree.

The active acceptance gate invokes the cross-phase migration timeout validator
before PostgreSQL execution. The validator can also be run independently with:

```bash
./tools/validation/validate_foundation_migration_timeouts.sh
```

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
8. Correctness-result reporting
9. Resource observation when the change affects executable test paths
10. Migration timeout and execution-contract validation when migration files
    change
11. Deployment and operational controls when the change crosses the database
    boundary

A performance observation is not a performance failure. Performance budgets
must be based on representative, comparable runs and governed explicitly.

## README Preservation Rule

This README is the primary project mission, scope, architecture, progress, and
operating statement. Phase packages must update it in place without reducing
it to a short status summary.

At minimum, future versions must preserve substantive sections covering:

- Project Mission
- Platform Scope and Long-Term Direction
- Initial Operational Direction
- Current Development Stage
- Staged Development Approach
- Core Principles
- Platform Layers
- Platform Foundation Scope
- Current Implementation Boundaries
- Migration Ranges
- Repository Layout
- Documentation
- SQL Foundation
- SQL Test Framework
- Definition of Progress
- Production Readiness
- Final Goal

A shorter navigation page belongs under `docs/` or another index file, not as
a replacement for this root README.

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
- Complete approval independence and separation-of-duties behavior
- Least-privileged application and operator roles
- Protected deployment and upgrade procedures
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

### Accepted Phase 5 Step 2 — Deployment Role Topology

Phase 5 Step 1 is accepted at 77 gate PASS checks and zero failures.

Phase 5 Step 2 implements a deployment tree outside the formally frozen
`sql/schema` tree, an exact deployment migration registry, 18 canonical
PostgreSQL role shells, and nine bounded service-to-capability memberships.

Step 2 creates no passwords, transfers no object ownership, and grants no
protected object privileges. Cluster-global role behavior is tested only in a
disposable PostgreSQL cluster.

The persistent-database parity report is now:

```bash
./tools/validation/validate_foundation_database_parity.sh dev_testing
```

Governing implementation record:

- [Phase 5 Step 2 — Deployment Manifest and PostgreSQL Role Topology](docs/architecture/foundation/phase-5-step-2-deployment-role-topology.md)

Active gate:

```bash
./tools/validation/phase-gates/validate_phase5_step2.sh
```

### Active Phase 5 Step 3 — Ownership and Default Privileges

Phase 5 Step 2 is accepted. Step 3 transfers the database and protected
objects away from the login-capable bootstrap identity and into the approved
`NOLOGIN` ownership roles.

Step 3 assigns:

- the database and `deployment_meta` to `issp_database_owner`;
- Platform Foundation schemas and objects to `issp_foundation_owner`;
- the `extensions` schema and extension member objects to
  `issp_extension_owner`.

It revokes `PUBLIC` database and protected-object access and establishes
creator-specific default privileges. Runtime object grants remain deferred to
Phase 5 Step 4.

Governing implementation record:

- [Phase 5 Step 3 — Ownership and Creator-Specific Default Privileges](docs/architecture/foundation/phase-5-step-3-ownership-and-default-privileges.md)

Active gate:

```bash
./tools/validation/phase-gates/validate_phase5_step3.sh
```

### Active Phase 5 Step 4 — Least-Privileged Runtime Grants

Phase 5 Step 4 grants only inherited database `CONNECT`, exact capability
schema `USAGE`, and controlled routine `EXECUTE` to the current bounded
production service identities.

No runtime or service role receives direct protected-table or sequence
privileges. Thirty-one approved routines execute as the non-login Foundation
owner with fixed `pg_catalog`-first search paths. Integration and monitoring
workers use bounded claim, completion, and retry APIs.

Governing implementation:

- [Phase 5 Step 4 — Least-Privileged Runtime Grants and Controlled Service APIs](docs/architecture/foundation/phase-5-step-4-least-privileged-runtime-grants.md)

Active gate:

```bash
./tools/validation/phase-gates/validate_phase5_step4.sh
```
