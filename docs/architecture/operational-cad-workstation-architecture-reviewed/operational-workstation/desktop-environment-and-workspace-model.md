# Desktop Environment and Workspace Model

> **Status:** Draft normative architecture with an initial reference direction.
>
> **Implementation status:** Not implemented or benchmarked.

## Purpose

This document defines the desktop shell, workspace behavior, and application-launch model for an Operational Workstation profile.

## Initial reference direction

The first profile should evaluate Arch Linux with i3wm because it provides a small runtime footprint, predictable window placement, text-based configuration, and simpler operational maintenance than a source-patched window manager.

dwm may be evaluated later for an appliance image, but it should not be the initial dependency while layouts, bindings, and operations are still changing.

The architecture does not permanently bind the platform to either window manager.

## Appliance behavior

Normal operators should not interact with:

- Package managers.
- General filesystem browsers.
- Developer tools.
- Unapproved terminal sessions.
- Desktop customization panels.
- General-purpose web browsing.
- Consumer synchronization clients.

The desktop should launch approved operational functions through a profile-controlled shell.

## Workspace model

Workspace definitions must be declarative and profile-specific.

A public-safety dispatch profile might define:

```text
1  Call intake
2  Active incidents
3  Map and resource board
4  Messaging
5  Records lookup
6  Supervisor tools
7  Operational health
8  Approved external resources
9  Administration
10 Recovery or maintenance
```

This is an example, not a universal platform layout.

## Workspace requirements

- A workspace has a stable purpose.
- Application placement is deterministic.
- Restart and reconnect behavior are defined.
- Multi-monitor placement has a single-monitor fallback.
- Unauthorized applications cannot be launched merely through a binding change.
- Profile changes are versioned, tested, and reversible.
- Operator personalization is bounded and must not break supportability, accessibility, auditability, or consistent emergency operation.

## Client model

The first implementation should compare at least:

- A hardened browser in application mode using a lightweight web client.
- A native client using a mature supported toolkit.

Electron or another bundled browser runtime should not be adopted by default. Any large runtime must justify its package, memory, update, attack-surface, and lifecycle costs.
