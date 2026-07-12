# Degraded Operation Model

> **Status:** Draft normative architecture.
>
> **Implementation status:** States and operator presentation are not yet implemented.

## Purpose

The workstation must present degraded conditions clearly and must never make old or incomplete information appear current.

## Required states

At minimum, the client must distinguish:

- **Live** — required services and subscriptions are current.
- **Delayed** — updates are arriving outside the normal latency budget.
- **Stale** — a resource or dataset has exceeded its freshness policy.
- **Offline** — the relevant connection or service is unavailable.
- **Resynchronizing** — the client is rebuilding state from a snapshot and ordered changes.
- **Restricted** — workstation trust or authorization permits only a reduced operation set.
- **Untrusted** — the workstation cannot perform protected operations.

## Presentation rules

- State is visible without requiring a hidden diagnostic screen.
- Meaning does not rely on color alone.
- Resource markers expose data age when stale or delayed.
- Recovered durable location is marked stale until a current device update arrives.
- Maps and cached reference data may remain usable when live overlays fail.
- Failed writes, queued telemetry, and unsent critical events must not be silently discarded.
- The client explains which capability is unavailable and what remains safe to use.

## Security behavior

Degraded availability must not cause automatic bypass of identity, authorization, scope, approval, or workstation-trust requirements.

Any emergency or break-glass workflow is a separately governed operation with explicit evidence, time bounds, alerts, and review.
