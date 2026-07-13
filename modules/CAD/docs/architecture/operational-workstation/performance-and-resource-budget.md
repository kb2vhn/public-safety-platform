# Performance and Resource Budget

> Status: Normative CAD target architecture.
>
> Implementation status: Initial measurement framework defined; final budgets require benchmark and field observations.

## Purpose

Performance is a functional, human-factors, security, and resilience requirement.

The console must be validated on the lowest supported production hardware profile, not only on developer systems.

## Budget principles

- Every significant workstation component has a resource budget.
- The console shell remains small and responsive.
- A high-resource workstation component cannot starve critical lower-resource workstation components.
- Performance measurements define start and end points.
- p50, p95, and p99 are reported where appropriate.
- Cold and warm behavior are distinguished.
- Tests use representative data and event volume.
- Averages do not hide long blocking stalls.
- Resource ceilings and restart behavior are validated together.
- Accessibility modes are included in performance testing.
- Degraded and recovery behavior are measured.

## Initial validation hardware

An initial low-cost validation profile should evaluate approximately:

- Four modern low-power CPU cores.
- 8 GB RAM.
- Integrated graphics.
- SSD storage.
- 1 Gb Ethernet.
- Two 1080p displays.
- Defined single-display fallback.

This is not an accepted minimum. Testing establishes the supported profile.

Higher-resolution, multi-display, or specialized profiles require separate benchmark artifacts and field observations.

## Measurement environment

Every result records:

- Hardware model.
- CPU.
- memory.
- storage.
- graphics device and driver.
- monitor arrangement.
- kernel.
- console release.
- WebKitGTK version.
- workstation component versions.
- network conditions.
- dataset size.
- event rate.
- active workstation components.
- accessibility settings.
- test duration.
- percentile method.

## Interaction measurements

Measure at minimum:

- Input to visible acknowledgment.
- input to completed local UI update.
- action submission to pending indication.
- server acknowledgment to committed indication.
- live event receipt to visible render.
- workspace switch.
- search initiation to first useful result.
- incident selection to complete primary view.
- map pan and zoom response.
- workstation component cold start.
- workstation component warm restart.
- state resynchronization.
- operator-context restoration.
- lock.
- unlock.
- operator handoff.
- maintenance-state transition.

## Responsiveness

The architecture does not accept phrases such as “fast,” “near zero,” or “within a few seconds” as final requirements.

Each accepted profile will define numeric thresholds for:

- p50.
- p95.
- p99.
- maximum blocking stall.
- maximum dropped or coalesced noncritical update rate.
- maximum time to visible degraded state.
- maximum time to safe automatic recovery.
- maximum time to declare recovery failure.

Numbers must be established through benchmark results, field observations, and governed change control.

## Resource measurements

Measure per workstation component and complete console:

- Resident memory.
- peak memory.
- sustained and burst CPU.
- thread and process count.
- file descriptors.
- disk read and write rate.
- cache size.
- queue size.
- network throughput.
- GPU memory and utilization where available.
- startup I/O.
- log volume.
- fault-bundle size.

## Resource governance

Each component profile declares:

- Normal expected range.
- warning threshold.
- degradation threshold.
- hard ceiling.
- action at each threshold.
- measurement and artifact collection.
- operator-visible effect.
- restart or disable policy.

A workstation component crossing a hard ceiling may be terminated to protect the rest of the console, but protected pending work must follow the local-state model.

## Mapping

Mapping tests should include:

- Base-map rendering.
- live resource overlays.
- multiple layers.
- labels.
- route or geofence display where used.
- offline or cached maps.
- large viewport changes.
- rapid live updates.
- GPU process failure.
- renderer restart.
- data resynchronization.

The map must not make incident entry or resource control unresponsive.

## Sustained workload

Short benchmarks are insufficient.

Testing should include:

- Full shift duration or equivalent soak.
- high event rate.
- memory growth.
- cache turnover.
- repeated workstation component restart.
- network interruption.
- log collector outage.
- storage pressure.
- lock and handoff cycles.
- display disconnect and reconnect.

## Fault and recovery budgets

Measure:

- Fault detection time.
- operator-visible degradation time.
- process termination time.
- replacement start time.
- IPC reconnect time.
- authoritative resynchronization time.
- operator-context restoration time.
- functional validation time.
- total operator-impact duration.
- escalation time after repeated failure.

## Release gates

A release cannot be promoted when:

- A critical interaction exceeds its accepted threshold.
- Memory or resource growth is unexplained.
- one workstation component can starve another.
- restart fails to restore context.
- degraded-state presentation is delayed beyond policy.
- log or fault diagnostic records causes unacceptable resource load.
- accessibility mode violates accepted thresholds without governed exception.
- results are not reproducible.

## Capacity observations and benchmark artifacts

Performance observations and benchmark artifacts becomes a versioned release artifact.

Changes to hardware minimums or budgets require:

- Recorded reason.
- representative benchmark.
- operational impact.
- security impact.
- cost impact.
- accessibility impact.
- Governed budget-change authorization.
