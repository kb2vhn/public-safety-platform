# Phase 6 Step 1 — Production Go Service Contract Freeze

> **Status:** Candidate contract checkpoint.
>
> **Implementation status:** Documentation and validation only.
>
> **Accepted predecessor:** Phase 5 production database security boundary at
> `phase-5-production-database-security-boundary-complete-v1`.

## Decision

Phase 6 begins production Go development only after freezing the service
boundary that consumes the accepted PostgreSQL security model.

Step 1 accepts the following direction:

- one production Go workspace;
- three bounded initial processes;
- exact process-to-database-role mapping;
- no universal application database identity;
- controlled PostgreSQL routines and approved views only;
- no runtime migration behavior;
- typed request and database adapters;
- explicit configuration, secret, timeout, transaction, health, shutdown,
  logging, metric, tracing, worker, dependency, build, and testing contracts;
- historical experiments isolated from production code;
- no production Go code introduced during this step.

## Initial Processes

```text
Foundation API
  PostgreSQL identity: issp_service_authorization

Integration delivery worker
  PostgreSQL identity: issp_service_integration_delivery

Monitoring delivery worker
  PostgreSQL identity: issp_service_monitoring_delivery
```

## Frozen Predecessor

The production Go boundary consumes but does not modify the Phase 5 accepted
implementation:

```text
Tag: phase-5-production-database-security-boundary-complete-v1
Commit: 9f8dbf9d909ef157df72b12511b165a689559093
```

Changes to the frozen Phase 5 deployment or executable validation tree require
explicit reopening, impact analysis, complete revalidation, and a new Phase 5
acceptance tag.

## Step 1 Evidence

The Step 1 gate validates:

- annotated Phase 5 tag type and exact target;
- current `dev` ancestry from the accepted Phase 5 implementation;
- unchanged accepted Foundation and Phase 5 deployment trees;
- unchanged executable Phase 5 predecessor gates and tests;
- the normative production Go service contract;
- the three exact database identity mappings;
- absence of production Go source, module, and generated artifacts;
- synchronized project and validation documentation;
- Bash syntax of the Step 1 gate;
- static or complete Phase 5 Step 8 predecessor revalidation.

## Next Step

Phase 6 Step 2 may create the production Go workspace and reproducible build
baseline under `go/platform/`. It must not yet implement protected business
operations or provision production credentials.

<!-- phase-6-step-1-accepted-result:start -->
## Accepted Result

Phase 6 Step 1 passed its complete gate with 63 PASS and 0 FAIL and was committed
at `77f9ead23f5275e97989ea8c59b0c9c44f0c5a0b`. Step 2 may build only within the frozen production service
contract.
<!-- phase-6-step-1-accepted-result:end -->
