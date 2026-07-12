# Workstation Performance Budget

> **Status:** Draft normative architecture.
>
> **Implementation status:** Initial targets require benchmarking and may be refined only with recorded evidence.

## Purpose

Performance is a functional and human-factors requirement. The workstation must be tested on the lowest supported production profile rather than developer hardware.

## Initial hardware profile

An initial validation profile should evaluate approximately:

- Four modern low-power CPU cores.
- 8 GB RAM.
- Integrated graphics.
- SSD storage.
- 1 Gb Ethernet.
- Two 1080p displays, with a defined single-display fallback.

The accepted minimum must be established through testing rather than assumption.

## Initial targets

| Metric | Initial target |
|---|---:|
| Power on to login ready | under 30 seconds |
| Login to operational ready | under 10 seconds |
| Workspace switch | no perceptible operational delay |
| Keyboard response | no perceptible operational delay |
| Warm base-map initialization | under 2 seconds |
| Common incident or resource search | under 500 ms |
| Live resource update presentation | under 500 ms on a healthy LAN |
| Client reconnect after a transient interruption | within a few seconds |
| Idle CPU | low single digits |
| Idle memory | explicitly measured and bounded |
| Warm static-map network use | near zero except cache validation |

## Feature budget

Every client feature must document:

- CPU and GPU impact.
- Resident and peak memory.
- Disk footprint and write rate.
- Network frequency, burst, and sustained bandwidth.
- Startup and workspace-switch impact.
- Common and worst-case latency.
- Background processing.
- Behavior under service, database, and network degradation.

## Failure threshold

A feature is not accepted merely because stronger hardware hides inefficient behavior. Budget changes require an architectural explanation, benchmark evidence, and approval.
