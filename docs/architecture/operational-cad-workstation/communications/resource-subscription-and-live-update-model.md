# Resource Subscription and Live Update Model

> **Status:** Draft normative architecture.
>
> **Implementation status:** Not implemented or concurrency tested.

## Purpose

Operational clients receive only the live state relevant to their authorized responsibilities rather than polling PostgreSQL or receiving every platform update.

## Connection model

A workstation should normally maintain one authenticated, bounded live-update connection to a Subscription Gateway. The gateway multiplexes authorized incident, resource, area, agency, assignment, and health subscriptions.

The architecture may initially use WebSocket transport, but message semantics must remain separable from that transport.

## Subscription types

- **Automatic operational subscriptions** derived from current assignments, governed scope, position, shift, or incident responsibility.
- **Temporary manual subscriptions** for an explicitly selected resource or incident, bounded by purpose and expiry.
- **Conditional subscriptions** for governed events such as emergency status or entry into an authorized area; these should follow after the basic model is proven.

## Subscription is not authorization

A request to subscribe never grants visibility.

The gateway must evaluate current:

- Operator and device identity.
- Session and workstation trust.
- Governed purpose and operation.
- Resource target and scope.
- Assignment and organizational relationship.
- Authorization policy and lease.
- Classification and risk state.

A subscription expires no later than the authority that permitted it and is re-evaluated when material context changes.

## Snapshot then changes

A new or recovering subscription must receive:

1. An authorized current snapshot.
2. A sequence or cursor identifying the snapshot boundary.
3. Ordered subsequent changes.
4. Gap detection.
5. Explicit resynchronization when continuity cannot be proven.

The client must not construct a supposedly current view from unbounded, unordered messages.

## Event treatment

High-frequency position updates may be coalesced so the client receives the newest useful state within the presentation budget.

Do not coalesce material operational transitions such as:

- Emergency activation.
- Assignment or release.
- Arrival or transport state.
- Loss of contact.
- Availability or crew change.
- Authorization or visibility revocation.

## PostgreSQL boundary

Do not create one persistent database listener, polling query, or transaction per workstation subscription.

The Go service may initially maintain in-memory indexes such as:

```text
resource -> authorized subscribers
incident -> authorized subscribers
scope    -> authorized subscribers
operator -> active connection
```

Durable state and publishable events should cross the database boundary through controlled APIs and transactional publication patterns where durability is required.

## Failure states

The gateway and client must distinguish live, delayed, stale, offline, and resynchronizing conditions. Missing sequence continuity must never be ignored.
