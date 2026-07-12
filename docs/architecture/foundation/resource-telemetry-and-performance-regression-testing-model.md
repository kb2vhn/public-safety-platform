# Resource Telemetry and Performance-Regression Testing Model

> **Layer:** Platform Foundation test and validation infrastructure
>
> **Phase:** 4 — Approval Independence and Separation of Duties
>
> **Step:** 2 — Structural Extension and Baseline Resource Observation
>
> **Status:** Normative testing contract; observation-only baseline collection
>
> **Correctness boundary:** Resource observations do not replace or weaken
> functional, structural, security, or concurrency assertions.

## 1. Purpose

Measure the execution cost of the Foundation SQL test suite while preserving a
strict distinction between correctness and resource use.

The initial implementation records comparable observations for duration, CPU,
memory, operating-system I/O counters, PostgreSQL database statistics, WAL
generation, and disposable-database size. It does not yet enforce performance
budgets.

## 2. Separate Outcomes

Every resource-aware test run reports three independent states:

```text
Correctness result: PASS or FAIL
Resource observation: RECORDED or NOT_RECORDED
Performance thresholds: NOT_EVALUATED
```

A correct test run does not become incorrect because it used more CPU, memory,
I/O, WAL, or elapsed time than another run.

A missing or malformed resource report is a test-infrastructure failure for a
gate that explicitly requires telemetry. It is not a functional assertion
failure inside the SQL test inventory.

## 3. Runner Boundary

The normal correctness runner remains:

```text
test-framework/sql/schema/scripts/test_foundation.sh
```

The resource-aware wrapper is:

```text
test-framework/sql/schema/scripts/test_foundation_with_resources.sh
```

The wrapper:

1. Completes its own dependency and PostgreSQL preflight.
2. Invokes the unchanged correctness runner with `--keep-database`.
3. Measures the runner process tree with GNU `time`.
4. Reads the normal summary and log.
5. Observes the retained disposable database.
6. Writes human-readable and machine-readable resource reports.
7. Drops a successful database unless retention was requested.
8. Returns the correctness runner's exit status.

The wrapper must not suppress, reinterpret, or convert SQL assertion failures.

## 4. Required Observations

### 4.1 Environment Fingerprint

Each report records:

- Host name
- Kernel and operating-system description
- Logical CPU count
- CPU model when available
- Installed memory
- PostgreSQL version and version number
- Connected PostgreSQL role
- Optional non-secret comparison label

A performance comparison is meaningful only when the relevant fingerprint is
compatible or the difference is explicitly accounted for.

### 4.2 Timing

The initial report records:

- Correctness-runner elapsed time
- Resource-collection elapsed time
- Migration and disposable-database setup duration
- Sequential-test duration
- Concurrency-test duration
- Result-finalization duration

Total elapsed time is measured at high resolution. Phase timings are derived
from the normal runner's timestamped log and currently have one-second
resolution.

### 4.3 Process-Tree Resource Use

GNU `time` records:

- User CPU seconds
- System CPU seconds
- Effective CPU utilization
- Maximum observed resident-set size
- Major and minor page faults
- Filesystem input and output operation counters
- Voluntary and involuntary context switches

Maximum resident-set size is the largest observed process value. It is not the
sum of all concurrently active PostgreSQL, shell, and worker processes.

### 4.4 PostgreSQL Observations

The retained disposable database is observed for:

- Database size
- Transactions committed and rolled back
- Shared blocks read and hit
- Derived cache-hit percentage
- Temporary files and bytes
- Deadlocks
- Tuple read and mutation counters

The wrapper also records the difference between cluster WAL locations captured
before and after the run. That value is an observed cluster-wide WAL change and
may include unrelated activity on a shared PostgreSQL instance.

## 5. Result Files

Resource reports are written beside the normal correctness outputs:

```text
test-framework/sql/test-results/
├── foundation_<run-id>-summary.txt
├── foundation_<run-id>.log
├── foundation_<run-id>-resources.txt
├── foundation_<run-id>-resources.json
├── latest-summary.txt
├── latest.log
├── latest-resources.txt
└── latest-resources.json
```

The JSON report is the machine-readable comparison contract. The text report is
for operator review.

These reports are resource observations. They are not automatically Assurance
Artifacts. A governed assessment may later register a reviewed, retained copy
as an Assurance Artifact through the applicable assurance process.

## 6. Baseline Collection

Phase 4 Step 2 begins observation-only baseline collection.

A useful baseline requires multiple successful runs with:

- The same or compatible host profile
- The same PostgreSQL major and comparable configuration
- The same migration and test manifests
- Comparable background workload
- Comparable storage and virtualization conditions
- No known host saturation or maintenance activity

Single-run minima or averages must not become budgets merely because they were
easy to measure.

## 7. Future Performance Budgets

A later governed step may define warning and failure thresholds for:

- Complete-suite elapsed time
- Phase-specific elapsed time
- CPU seconds or utilization
- Peak memory
- Temporary files and bytes
- Database growth
- WAL generation
- Unexpected disk I/O
- Deadlocks
- Repeated statistically meaningful regression

Budgets must identify the workload, environment profile, sample window,
statistical rule, owner, rationale, exception process, and revalidation
conditions.

No threshold is active in Phase 4 Step 2.

## 8. Performance-Regression Evaluation

A later regression evaluator should compare compatible runs using a bounded
window rather than one historical best result.

It should distinguish:

```text
IMPROVED
WITHIN_BASELINE
REGRESSION_WARNING
REGRESSION_FAILURE
NOT_COMPARABLE
NOT_EVALUATED
```

The evaluator must retain raw observations, comparison inputs, and the applied
budget version. It must not hide a correctness failure behind a performance
summary.

## 9. Failure Semantics

### Correctness Failure

A SQL assertion, migration, concurrency proof, or normal runner failure remains
a correctness failure. The failed database is retained by default.

### Telemetry Infrastructure Failure

A required resource report that cannot be generated, parsed, or matched to the
correct run is a validation-infrastructure failure.

### Resource Threshold Result

There is no resource-threshold failure in Step 2. Values are recorded for
baseline and trend analysis only.

## 10. Security and Data Handling

Resource reports must not contain:

- Passwords
- Connection secrets
- Lease secrets
- Private keys
- Unnecessary SQL data
- Unbounded command output
- Sensitive record contents

Labels must be non-secret and single-line.

## 11. Phase 4 Step 2 Integration

The approval-independence migration and structural SQL test remain functional
work:

```text
sql/schema/migrations/foundation/
└── 083_postgresql_approval_independence_and_separation_of_duties.sql

test-framework/sql/tests/foundation/
└── 170_approval_independence_and_separation_of_duties_structure.sql
```

Resource observation is test infrastructure:

```text
test-framework/sql/schema/scripts/
└── test_foundation_with_resources.sh
```

The SQL test contributes functional assertions to the correctness total. The
resource wrapper contributes no SQL PASS rows and no performance threshold.

## 12. Validation Expectations

Phase 4 Step 2 validation requires:

- The normal correctness summary to pass
- The expected migration and test counts
- The expected SQL assertion totals
- A resource JSON report with the same run identifier
- `RECORDED` resource-observation status
- `NOT_EVALUATED` threshold status
- Positive elapsed, CPU, memory, and database-size fields
- Nonnegative PostgreSQL and I/O counters
- Zero deadlocks
- A complete environment fingerprint

The first successful Step 2 run becomes a baseline observation, not a budget.

## 13. Related Documents

- [Performance, Efficiency, and Resource Governance](performance-efficiency-and-resource-governance-model.md)
- [Observability, Health, and Operational Telemetry](observability-health-and-operational-telemetry-model.md)
- [Approval Independence and Separation of Duties](approval-independence-and-separation-of-duties-model.md)
- [SQL Migration Map](sql-migration-map.md)
