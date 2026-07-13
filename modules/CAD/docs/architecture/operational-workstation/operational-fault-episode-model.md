# Operational Fault Episode Model

> Status: Normative CAD target architecture.
>
> Implementation status: Event contracts, storage, and support workflow are not yet implemented.

## Purpose

An **Operational Fault Episode** is the complete correlated record of a console failure from first symptom through detection, containment, recovery, support response, root cause, corrective change, validation, and closure.

It is not one log line and it is not owned only by the failed component.

## Objectives

The episode must allow:

- Operators to understand the immediate impact.
- Tier-one support to identify the affected workstation and capability.
- Tier-two support to reconstruct local and dependency behavior.
- Engineering to correlate code, release, package, protocol, and resource observations.
- Security to identify malicious or suspicious behavior.
- Management to understand recurrence and operational impact.
- Auditors to verify detection, response, corrective action, and closure.

## Episode creation

The console coordinator, independent health service, or supervisor must be able to create the episode even when the failed workstation component cannot emit events.

An episode is opened when a configured threshold is met, such as:

- Workstation Component health failure.
- renderer crash.
- service crash.
- restart loop.
- resource-budget violation.
- local IPC authentication failure.
- corrupted local state.
- action outcome unknown.
- release incompatibility.
- trust-assertion failure.
- security isolation.
- failed update or rollback.
- repeated degraded-state transition.
- administrator intervention affecting console operation.

## Episode identifiers

Every episode has a globally unique identifier such as:

```text
OFE-2026-000184
```

All contributing events carry the episode identifier when known.

Events created before correlation retain their original identifier and are linked later rather than rewritten invisibly.

## Event structure

Each event should include:

- Fault episode identifier.
- event identifier.
- parent and causal event identifiers.
- event type and severity.
- workstation identifier.
- console session identifier where applicable.
- operator-session reference where appropriate.
- component identifier.
- component instance identifier.
- console and workstation component release identifiers.
- package and configuration references.
- observed time.
- source event time.
- monotonic sequence or clock reference.
- state before and after.
- action taken.
- outcome.
- diagnostic-record references.
- support owner.
- confidentiality classification.

## Event sources

Potential contributors include:

- Console coordinator.
- systemd.
- Linux kernel.
- native component host.
- WebKit web, network, and GPU processes.
- Go component service.
- local IPC broker or socket.
- local state service.
- platform API.
- workstation trust agent.
- firewall.
- resource monitor.
- update and release agent.
- remote administration recorder.
- operator-visible notification surface.
- external integration adapter.

## Example event chain

```text
14:07:12.083  Map response exceeded normal deadline
14:07:12.607  Map state changed HEALTHY → DELAYED
14:07:13.102  Map state changed DELAYED → DEGRADED
14:07:13.104  Operator degradation banner displayed
14:07:14.118  Map UI became unresponsive
14:07:14.120  Map state changed DEGRADED → FAILED
14:07:14.123  Operator shown "Mapping unavailable — recovering"
14:07:14.127  Incident and resource workstation components verified healthy
14:07:14.131  Map termination requested
14:07:15.002  Map process terminated
14:07:15.014  Exit state and resource observations captured
14:07:15.050  Restart initiated
14:07:16.337  New process acquired IPC endpoint
14:07:16.581  Incident context restored
14:07:16.820  Unit positions resynchronized
14:07:17.006  Functional health verified
14:07:17.009  Map state changed RESYNCHRONIZING → HEALTHY
14:07:17.012  Operator shown "Mapping restored"
```

## Support lifecycle

An episode may progress through:

- Open.
- automatically recovering.
- recovered pending review.
- support acknowledged.
- triaged.
- escalated.
- known problem linked.
- root cause identified.
- corrective change prepared.
- correction in Pre-production.
- correction released.
- validation complete.
- closed.
- reopened.

Recovery does not automatically close the episode.

## Operational impact

The episode records:

- Capabilities unavailable.
- start and end of operator impact.
- affected operators and positions by reference.
- alternate procedures invoked.
- pending or outcome-unknown actions.
- data freshness impact.
- external integrations affected.
- whether the workstation remained in service.
- whether operator acknowledgment was required.
- whether the event was security relevant.

## Sensitive information

Diagnostic records should prefer identifiers, hashes, versions, and bounded diagnostic records over full operational content.

For example, record:

```text
incident_id: INC-2026-002341
incident_projection_hash: sha256:...
selected_layer_ids:
  - streets
  - units
```

rather than copying the complete narrative into general diagnostic storage.

Sensitive captures require explicit authorization, classification, retention, and access controls.

## Diagnostic bundle

A bounded diagnostic bundle may include:

- Relevant journal ranges.
- process exit and coredump metadata.
- resource timeline.
- workstation component and protocol versions.
- configuration digests.
- state transition history.
- IPC error summaries.
- network dependency results.
- renderer failure details.
- integrity-verification records.
- update history.
- administrator session references.

A bundle must not silently contain secrets, private keys, unrestricted memory dumps, or unnecessary protected records.

## Root cause and correction

Closure requires, where applicable:

- Root-cause statement.
- contributing factors.
- detection quality.
- recovery quality.
- corrective change.
- release containing the correction.
- regression test.
- fault-injection results or reproduction artifacts.
- support knowledge update.
- recurrence assessment.
- closure authority.

## Integrity and retention

Episode records must be:

- Append-oriented.
- time synchronized.
- exported off-host.
- integrity protected.
- access controlled.
- searchable by workstation, workstation component, release, symptom, and cause.
- retained according to operational, legal, security, and contractual policy.
- independent of one monitoring vendor.

## Metrics

Derived metrics may include:

- Mean detection time.
- mean operator-impact duration.
- mean automatic recovery time.
- mean support acknowledgment time.
- recurrence by workstation component and release.
- restart-loop frequency.
- unresolved outcome-unknown count.
- percentage of episodes with permanent correction.
- false-positive rate.
- degraded-time by workstation profile.
