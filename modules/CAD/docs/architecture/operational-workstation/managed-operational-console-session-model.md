# Managed Operational Console Session Model

> Status: Normative CAD target architecture.
>
> Implementation status: Reference direction selected; window manager, display server, and production profile remain to be validated.

## Purpose

This document defines the operator's controlled graphical environment.

The term **Managed Operational Console Session** is used instead of kiosk mode because the console is not merely one browser window. It is a governed session that presents one operational suite composed of multiple independently supervised workstation components.

## Session behavior

The normal operator path is:

```text
Trusted workstation boot
        ↓
Verified operating-system and console release
        ↓
Managed graphical session starts
        ↓
Global console status surface becomes available
        ↓
Operator authenticates to the Platform
        ↓
Authorized workspace and accessibility profile load
        ↓
Operational workstation components enter ready or explicit degraded states
```

The operator must not need to launch applications, manage windows, inspect the desktop, or understand underlying processes.

## Operator account

The normal console user is an unprivileged Linux account or equivalent restricted session identity.

The operator account must not have:

- `sudo` or equivalent administrative rights.
- Interactive SSH access.
- Package-management authority.
- A general-purpose application launcher.
- An unrestricted shell or terminal.
- An unmanaged browser.
- Permission to modify system services or unit files.
- Permission to alter the approved release bundle.
- Access to another operator's local data.
- Unrestricted access to local runtime sockets.
- Permission to escape into a general-purpose desktop session.

The operator account may access only the display, input, audio, removable-device, local file, and IPC capabilities required by the approved workstation profile.

## Console coordinator

A small console coordinator owns:

- Session startup and shutdown coordination.
- Global operator and workstation status.
- Monitor and workspace placement.
- Workstation Component readiness and health presentation.
- Global alert presentation.
- Keyboard-command routing.
- Operator lock and handoff initiation.
- Controlled workstation component restart requests.
- Accessibility profile loading.
- Maintenance and out-of-service presentation.
- Correlation with Operational Fault Episodes.

The coordinator does not own platform business authority.

It must not decide whether an incident can be closed, whether a unit may be dispatched, whether restricted information may be displayed, or whether a policy requirement may be bypassed.

## Window and workspace behavior

The console may use a controlled window manager or compositor to place borderless workstation component windows into governed screen regions.

The implementation must prevent ordinary operators from:

- Moving critical windows into hidden positions.
- Closing required workstation component windows.
- resizing workstation components into unusable layouts.
- placing an untrusted window above a critical alert.
- opening unmanaged windows.
- changing the active workspace outside the approved profile.
- creating persistent layout drift.

To the operator, the suite may appear as one seamless application even when the regions are separate operating-system processes.

## Display profiles

Each accepted profile defines:

- Supported monitor count.
- Supported resolutions and scaling factors.
- Physical arrangement assumptions.
- Primary status and alert surface.
- Workspace regions.
- Single-display fallback.
- Loss-of-display behavior.
- Hot-plug policy.
- Accessibility scaling and magnification behavior.
- Maximum information density.
- Required visibility of freshness and degraded-state indicators.

Loss of one display must not silently hide critical information. The coordinator must move or summarize required alerts and essential controls onto an available display.

## Input profiles

Profiles may support keyboard, pointing device, touch, alternate input, foot controls, barcode or card readers, or other approved devices.

Keyboard-first operation must not become keyboard-exclusive operation.

Every critical shortcut must have:

- A visible accessible alternative.
- A collision review.
- A risk classification.
- A documented focus effect.
- A confirmation policy where appropriate.
- An owner and governed change-authorization state.
- Automated or manual test coverage.

## Automatic startup

The console suite starts automatically after the managed graphical session becomes ready.

The system must not present the operator with:

- A package update prompt.
- A crash dialog from a general desktop environment.
- A first-run browser screen.
- A desktop notification unrelated to the console.
- A screen saver advertisement or consumer service.
- A privilege prompt.
- A raw system error without operator-safe explanation.

Underlying diagnostic detail is recorded for support while the operator receives clear operational language.

## Maintenance state

Remote administration may continue without taking control of the operator display.

When operator-impacting work is necessary, the console enters an explicit state such as:

- Maintenance scheduled.
- Maintenance pending operator acknowledgment.
- Workstation Component maintenance in progress.
- Console out of service.
- Restart required.
- Reboot required.
- Validation in progress.
- Maintenance completed.
- Maintenance failed; previous release restored.

Maintenance controls must not quietly obscure an active operator session.

## Session termination

Normal session termination must:

- Complete or safely persist permitted drafts.
- Stop accepting new protected actions.
- resolve or expose pending and outcome-unknown actions.
- revoke local workstation component capabilities.
- clear operator-specific renderer and native state.
- remove per-session runtime directories and sockets.
- clear or rotate clipboard and temporary files according to policy.
- record the termination reason.
- leave the workstation ready for the next governed session.

A workstation reboot is not the normal shift-handoff mechanism.
