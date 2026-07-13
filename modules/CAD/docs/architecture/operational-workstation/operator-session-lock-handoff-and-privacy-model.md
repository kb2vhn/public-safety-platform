# Operator Session, Lock, Handoff, and Privacy Model

> Status: Normative CAD target architecture.
>
> Implementation status: Not yet implemented or field validated.

## Purpose

This document governs the lifecycle of an operator on a shared operational console.

A 24-hour console must support lock, unlock, relief, handoff, sign-out, reassignment, and forced revocation without exposing one operator's information or losing the operational state required by the next operator.

## Identity separation

The Linux console account is not the authoritative operator identity.

The workstation may run one restricted operating-system session while the Platform establishes and governs individual operator sessions.

Each operator session is bound to:

- Verified operator identity.
- Workstation identity.
- console-session identifier.
- approved organization and scope.
- current operational assignment.
- Authentication Assertion and session step-up records.
- session lifecycle.
- current trust and authorization state.
- accessibility and workspace preference references.

## Lock

Lock protects the current operator session without implying sign-out.

A lock must:

- Obscure protected operational content.
- stop ordinary operator input from reaching workstation components.
- retain only state permitted by policy.
- keep critical machine-level alerts available where safe.
- prevent another person from acting as the locked operator.
- record lock cause and time.
- require current reauthentication or another approved unlock method.
- re-evaluate session and workstation trust before restoring protected operation.

A screen blanker alone is not a lock.

## Automatic lock

The profile defines:

- Inactivity threshold.
- warning period.
- operations that temporarily suppress automatic lock.
- maximum suppression duration.
- behavior during active critical workflows.
- supervisor or policy overrides.
- audit requirements.

Automatic lock must not be disabled casually because the console is physically controlled.

## Unlock

Unlock requires:

- Current operator authentication.
- valid session or governed re-establishment.
- current workstation trust.
- current scope and shift state.
- workstation component readiness or explicit degraded presentation.
- restoration of the correct operator context.

Failed unlock attempts are rate limited and recorded.

## Handoff

A handoff transfers use of the physical console without transferring the former operator's authority.

The handoff process must:

1. Identify pending, queued, conflicted, and outcome-unknown actions.
2. identify operator-owned drafts.
3. require disposition according to workflow.
4. preserve shared operational projections.
5. remove or isolate former-operator private state.
6. revoke former-operator local capabilities.
7. terminate or close former-operator platform sessions as required.
8. authenticate the incoming operator.
9. load the incoming operator's approved workspace and accessibility profile.
10. re-evaluate current workstation and workstation component health.
11. present any unresolved operational items explicitly.
12. record the complete handoff.

## Shared and private state

Each local state item must declare whether it is:

- Workstation-shared operational state.
- Team or position-shared state.
- Operator-private state.
- operator-owned draft.
- security-sensitive state.
- disposable presentation state.

Examples of information that may require operator isolation include:

- Search history.
- clipboard contents.
- private messages.
- draft narratives.
- personal accessibility preferences.
- recent record lists.
- authentication artifacts.
- notification acknowledgments.
- local export staging.
- support screenshots or diagnostics.

A new operator must not inherit private state accidentally.

## Operational continuity

Handoff must not unnecessarily erase shared operational awareness.

The incoming operator may need to see:

- Active incidents.
- assigned resources.
- current alerts.
- integration failures.
- workstation component degraded states.
- unresolved outcome-unknown actions.
- pending team work.
- stale-data warnings.

The console must distinguish shared continuity from former-operator authority.

## Supervisor-assisted handoff

A supervisor may assist with a handoff, but must not impersonate either operator.

Any override or forced transition requires:

- Named supervisor identity.
- reason.
- affected operator and workstation.
- actions taken.
- unresolved work.
- time bounds.
- notifications.
- review where required.

## Forced lock and revocation

Security or operational authorities may force a lock, restrict the console, or revoke the operator session.

The workstation must respond to:

- Account suspension.
- employment-state change.
- shift revocation.
- workstation trust failure.
- session revocation.
- security isolation.
- emergency policy activation.

If connectivity prevents current revocation confirmation, the workstation follows explicit offline policy and presents the resulting restricted or untrusted state.

## Crash and reboot

After abnormal termination or reboot, the console must not automatically restore protected operator content before authentication.

Recoverable local state is associated with its prior operator and session and is released only after:

- identity verification.
- policy evaluation.
- integrity verification.
- replay or conflict checks.
- current authorization.

## Clipboard

Clipboard policy must define:

- permitted content types.
- maximum retention.
- component-to-component access.
- clearing on lock.
- clearing on handoff.
- sensitive-content restrictions.
- remote-support behavior.
- accessibility exceptions.
- audit behavior.

Clipboard history is disabled unless explicitly approved.

## Privacy-clearing records

The workstation must produce privacy-clearing records showing that handoff and sign-out completed required clearing actions without recording unnecessary protected content.

Privacy-clearing records may include:

- state categories cleared.
- capability revocation results.
- temporary-path cleanup result.
- clipboard-clear result.
- renderer-storage purge result.
- local queue transfer or retention result.
- new operator profile load result.
