# Dispatcher Capability Catalog

> **Document status:** Normative CAD requirements catalog
>
> **Implementation status:** Not implemented
>
> **Purpose:** Convert the dispatcher-workspace brainstorm into traceable
> requirements that can later map to architecture, controlled operations, tests,
> and release acceptance.

## Requirement Language

- **Must** identifies a required behavior.
- **Should** identifies a strong design expectation that requires an explicit
  reason when not implemented.
- **May** identifies an optional capability.
- A requirement is not implemented until an accepted executable artifact and
  applicable tests prove it.

## Operational Awareness

| ID | Requirement |
|---|---|
| CAD-DSP-001 | The dispatcher must be able to determine what is happening, where it is happening, which resources are available, which resources are assigned, and what requires attention. |
| CAD-DSP-002 | The workspace must identify the authenticated operator, active dispatch position, assigned agencies, disciplines, and scopes. |
| CAD-DSP-003 | The workspace must expose CAD and integration degradation with operational consequences. |
| CAD-DSP-004 | Current, stale, estimated, unconfirmed, queued, failed, conflicted, and committed state must be distinguishable. |
| CAD-DSP-005 | Critical meaning must not depend on color, sound, position, shape, animation, or one input method alone. |
| CAD-DSP-006 | The workspace should preserve stable logical regions during background updates. |
| CAD-DSP-007 | Essential operation must remain possible in a supported single-monitor configuration. |
| CAD-DSP-008 | Multi-monitor layouts may be configurable without changing the meaning of core workflows. |

## Incident Queue

| ID | Requirement |
|---|---|
| CAD-DSP-020 | The dispatcher must have an active incident queue. |
| CAD-DSP-021 | A queue entry must expose incident identifier, priority, type, location summary, scope, received time, ownership, assignment state, and active attention state. |
| CAD-DSP-022 | The queue must identify incidents awaiting dispatch. |
| CAD-DSP-023 | The queue must identify incidents with unread or materially changed information. |
| CAD-DSP-024 | The queue must identify active timers and escalations. |
| CAD-DSP-025 | The queue must identify responder-safety warning state without exposing restricted detail to unauthorized users. |
| CAD-DSP-026 | The queue should support governed filtering and grouping by agency, discipline, scope, priority, ownership, assignment, and lifecycle state. |
| CAD-DSP-027 | Queue sorting or filtering must not silently change the selected incident. |
| CAD-DSP-028 | Virtualization or pagination must not misrepresent a partial list as the complete operational queue. |

## Selected Incident

| ID | Requirement |
|---|---|
| CAD-DSP-040 | Selecting an incident must establish one coherent operational context. |
| CAD-DSP-041 | The selected incident must expose identity, priority, classification, lifecycle state, ownership, and elapsed time. |
| CAD-DSP-042 | The selected incident must distinguish reported, caller, verified, staging, destination, and other location roles. |
| CAD-DSP-043 | Caller or reporting-party information must be purpose-bound and access-controlled. |
| CAD-DSP-044 | The selected incident must expose assigned resources and assignment lifecycle. |
| CAD-DSP-045 | The selected incident must expose the append-oriented operational timeline. |
| CAD-DSP-046 | The selected incident must expose active alerts, timers, premise information, hazards, and related incidents when authorized. |
| CAD-DSP-047 | Common incident actions should be available without navigating through unrelated windows. |
| CAD-DSP-048 | Corrections must preserve the original material record and create accountable lineage. |
| CAD-DSP-049 | Closing, reopening, transferring, or cancelling an incident must use controlled operations. |

## Units and Resources

| ID | Requirement |
|---|---|
| CAD-DSP-060 | The dispatcher must have a unit and resource board. |
| CAD-DSP-061 | A resource entry must expose identifier, agency, discipline, current status, status age, assignment, and availability. |
| CAD-DSP-062 | Availability and dispatchability must be distinct. |
| CAD-DSP-063 | A resource entry should expose capabilities, crew summary, station or response area, communications reference, and last contact when authorized. |
| CAD-DSP-064 | Current location must include source, age, confidence, and degradation state. |
| CAD-DSP-065 | A stale location must not appear current. |
| CAD-DSP-066 | A unit assignment must distinguish recommended, proposed, committed, delivered, acknowledged, active, completed, cancelled, and failed state as applicable. |
| CAD-DSP-067 | Concurrent assignment of one unit must produce one authoritative result when single assignment is required. |
| CAD-DSP-068 | Exceptional status or assignment transitions must require a reason. |

## Recommendations and Response Plans

| ID | Requirement |
|---|---|
| CAD-DSP-080 | The system may recommend resources but must not silently commit a recommendation. |
| CAD-DSP-081 | A material recommendation must identify the applicable response plan and version. |
| CAD-DSP-082 | A recommendation must explain why a resource was included, ranked, or excluded. |
| CAD-DSP-083 | Recommendation logic must consider capability, availability, dispatchability, scope, location freshness, policy, and operational constraints. |
| CAD-DSP-084 | Recommendations must expire or be reevaluated when material inputs change. |
| CAD-DSP-085 | An authorized operator may override a recommendation. |
| CAD-DSP-086 | An override must preserve the original recommendation and record actor, authority, reason, and selected resource. |
| CAD-DSP-087 | A response-plan exception must not silently modify the governed response-plan version. |

## Location, Map, Premise, and Hazards

| ID | Requirement |
|---|---|
| CAD-DSP-100 | The dispatcher must be able to inspect incident and unit location without depending solely on a map. |
| CAD-DSP-101 | Map selection and alternative-list selection must establish consistent context. |
| CAD-DSP-102 | Location data must retain source, effective time, recorded time, confidence, and verification state. |
| CAD-DSP-103 | Jurisdiction and response-area derivation must expose failure or uncertainty. |
| CAD-DSP-104 | Premise information must support structured access, facility, hazard, and response context. |
| CAD-DSP-105 | Sensitive access information must be classified and limited to operational need. |
| CAD-DSP-106 | A responder-safety warning must retain source, verification, review, expiration, organization, and lineage. |
| CAD-DSP-107 | Unverified free text must not automatically become a permanent premise warning. |
| CAD-DSP-108 | Map-provider failure must not remove essential location text or controlled CAD operation. |

## Alerts and Timers

| ID | Requirement |
|---|---|
| CAD-DSP-120 | Alerts must identify severity, source, affected target, age, required action, owner, acknowledgment, escalation, and resolution state. |
| CAD-DSP-121 | Acknowledging an alert must not mean the condition is resolved. |
| CAD-DSP-122 | Alert acknowledgment must be attributable and authorized. |
| CAD-DSP-123 | Alert resolution must identify the resolving condition or disposition. |
| CAD-DSP-124 | Repeated conditions must be deduplicated without hiding material changes. |
| CAD-DSP-125 | Suppression must be governed, time-bounded, attributable, and safety constrained. |
| CAD-DSP-126 | A timer must identify its policy version, start event, threshold, escalation, and affected workflow. |
| CAD-DSP-127 | Critical alerts must persist according to policy until acknowledged or resolved. |
| CAD-DSP-128 | Alert presentation must provide accessible visual, textual, audible, or programmatic equivalents appropriate to urgency. |

## Commands and Actions

| ID | Requirement |
|---|---|
| CAD-DSP-140 | High-frequency essential actions must be keyboard operable. |
| CAD-DSP-141 | A command must resolve to explicit targets and a proposed governed operation. |
| CAD-DSP-142 | Ambiguous commands must not commit until ambiguity is resolved. |
| CAD-DSP-143 | High-impact actions must expose material consequences before commit when operationally appropriate. |
| CAD-DSP-144 | The interface must report committed, rejected, pending, queued, failed, expired, or conflicted results accurately. |
| CAD-DSP-145 | Plain-language interpretation must not grant authority. |
| CAD-DSP-146 | Background refresh must not move keyboard focus or discard valid operator input. |
| CAD-DSP-147 | Reauthentication or step-up should preserve safe unsaved work. |
| CAD-DSP-148 | Destructive or irreversible actions must not be hidden behind unlabeled icons or transient gestures. |

## Communications and Integrations

| ID | Requirement |
|---|---|
| CAD-DSP-160 | CAD must distinguish a committed platform action from successful external delivery. |
| CAD-DSP-161 | External messages must retain provider identity, contract version, source identity, receipt time, and disposition. |
| CAD-DSP-162 | Duplicate external messages must not create duplicate operational effect when single effect is required. |
| CAD-DSP-163 | Failed, queued, retried, expired, and delivered communications must be distinguishable. |
| CAD-DSP-164 | Recording systems should be referenced through governed identifiers rather than copied indiscriminately into incidents. |
| CAD-DSP-165 | Provider-specific behavior must remain inside replaceable adapters. |
| CAD-DSP-166 | Integration health must state the affected capability and operational consequence. |

## Authorization and Supervisory Control

| ID | Requirement |
|---|---|
| CAD-DSP-180 | Normal dispatcher access must be limited by identity, organization, position, scope, purpose, operation, target, session, policy, and current authority. |
| CAD-DSP-181 | A normal dispatcher account must not include user administration, security administration, unrestricted export, audit deletion, or direct protected-table writes. |
| CAD-DSP-182 | Supervisory operations must remain distinct from unrestricted administration. |
| CAD-DSP-183 | Material supervisor overrides must require a reason and durable history. |
| CAD-DSP-184 | Sensitive access and bulk export must be purpose-bound and auditable. |
| CAD-DSP-185 | No ordinary identity or accumulated role set may provide unrestricted CAD authority. |
| CAD-DSP-186 | Break-glass access must be explicit, limited, time-bound, attributable, accessible, and reviewable. |
| CAD-DSP-187 | Approval Action recording, stage satisfaction, Approval Request finalization, Authorization Decision, Authorization Lease continuity, CAD commit, and external delivery must remain distinguishable. |
| CAD-DSP-188 | An approval must remain a bounded policy input and must not be represented as permission or a committed CAD action. |
| CAD-DSP-189 | A local client, cache, or queue must not create or finalize Foundation approval or authorization records. |
| CAD-DSP-190 | Retryable serialization, deadlock, and conflict outcomes must remain distinguishable from policy denial. |

## Degraded Operation

| ID | Requirement |
|---|---|
| CAD-DSP-200 | The dispatcher must be told which capability is degraded and what remains authoritative. |
| CAD-DSP-201 | The workspace must distinguish locally recorded, queued, pending authoritative validation, rejected, expired, conflicted, reconciled, and authoritatively committed actions. |
| CAD-DSP-202 | Offline or queued operation must define maximum authority and conflict behavior. |
| CAD-DSP-203 | Reconciliation must preserve local action, central state, conflict, disposition, and resulting canonical state. |
| CAD-DSP-204 | Recovery must not be declared complete until required queues, conflicts, delivery, and operational checks are resolved. |
| CAD-DSP-205 | Degraded operation must preserve accessible essential interaction. |

## Accessibility and Human Factors

| ID | Requirement |
|---|---|
| CAD-DSP-220 | Essential CAD workflows must be fully keyboard operable. |
| CAD-DSP-221 | Focus order and active context must remain predictable. |
| CAD-DSP-222 | Unit, incident, priority, alert, timer, queue, staleness, and degradation state must be programmatically exposed where supported. |
| CAD-DSP-223 | Maps must provide an equivalent synchronized non-map representation. |
| CAD-DSP-224 | Critical alerts must not depend on one sensory channel. |
| CAD-DSP-225 | High-density operation must retain stable landmarks, logical region navigation, and clear context. |
| CAD-DSP-226 | Accessibility preferences should follow the authenticated operator without requiring medical disclosure. |
| CAD-DSP-227 | User preferences must not suppress mandatory life-safety or security controls without governed authority. |
| CAD-DSP-228 | Accessibility acceptance requires automated, manual, assistive-technology, degraded-operation, and representative workflow evaluation. |

## Test Traceability

Each implemented requirement should eventually map to:

- Governing architecture.
- Protected operation.
- SQL or service artifact.
- Positive test.
- Negative test.
- Concurrency test when applicable.
- Accessibility test when applicable.
- Resource observation when applicable.
- Phase gate.
- Acceptance record.

## Machine-Readable Registration

The authoritative seed register for these `CAD-DSP-*` identifiers is:

```text
modules/CAD/requirements/cad-requirements.yaml
```

Every identifier and normative statement in this catalog must appear exactly
once in that register. The current entries remain not implemented, not tested,
and not evaluated for acceptance.
