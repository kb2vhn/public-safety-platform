# Remote Management and Session Recording Model

> Status: Normative CAD target architecture.
>
> Implementation status: OpenSSH is the initial transport direction; bastion, certificate authority, recorder, and storage are not yet implemented.

## Purpose

Operational Workstations require secure remote administration for automation, investigation, recovery, update, and controlled maintenance without turning the operator workspace into a support desktop.

All interactive administrative SSH activity must be attributable and completely recorded, including terminal input, terminal output, timing, privilege transitions, and session outcome.

## Principles

- Administration is performed by named identities.
- Shared administrative accounts are prohibited.
- The operator account cannot use SSH.
- SSH is a transport, not the authorization system or source of truth.
- Access originates only from approved management paths.
- Routine management should not take over the operator display.
- Interactive sessions are tied to a support, change, incident, or emergency purpose.
- Recordings are retained off-host.
- Target-side audit and diagnostic records supplement rather than replace independent recording.
- Root access on the target cannot be trusted to preserve the only authoritative recording.

## Access path

The preferred path is:

```text
Named administrator
        ↓
Approved managed source device
        ↓
Administrative bastion or access gateway
        ↓
Strong authentication and authorization
        ↓
Session recording established
        ↓
Target workstation SSH
        ↓
Target-side recorder and restricted administrative shell
```

Direct workstation access requires an explicit governed deployment authorization and, when policy requires it, a finalized Foundation Approval Request.

## Authentication

The initial model should prefer:

- Short-lived SSH certificates or equivalent centrally governed credentials.
- hardware-backed or phishing-resistant administrator authentication.
- source-device trust.
- named user identity.
- explicit target authorization.
- time-bounded access.
- revocation capability.

Password-only SSH authentication is prohibited for normal administration.

## Network restrictions

- `sshd` listens only on approved management addresses or interfaces where practical.
- Host firewall permits only approved sources.
- Upstream controls independently restrict access.
- Internet-originated SSH is denied.
- operator and ordinary user networks are denied.
- access attempts are exported off-host.
- break-glass paths are disabled or strongly restricted until activated.

## Complete terminal recording

The recording must capture:

- Session identifier.
- administrator identity.
- source device and network.
- SSH certificate or key identity.
- target workstation.
- start and end time.
- terminal input.
- terminal output.
- input and output timing.
- terminal resize events.
- disconnect cause.
- privilege transitions.
- commands and responses.
- affected services where determinable.
- related ticket or episode.
- console release before and after where relevant.

Ordinary shell history is not sufficient.

## Recording layers

### Gateway recording

The gateway records the interactive session before target compromise or root privilege can affect the target-side recorder.

### Target recording

The workstation records:

- SSH authentication.
- forced-command or recorder startup.
- local terminal I/O where supported.
- process execution and privilege changes.
- `sudo` activity.
- service changes.
- package and release operations.
- local session end.

Differences between gateway and target audit records are security relevant.

## Recording sensitivity

Complete terminal input and output may contain:

- Passwords entered into prompts.
- recovery secrets.
- API tokens.
- database connection strings.
- private operational information.
- sensitive search terms.
- accidentally pasted private keys.

Recordings are therefore highly restricted security records.

They must be:

- Encrypted in transit and at rest.
- stored off-host.
- access controlled by separate roles.
- integrity protected.
- retained by policy.
- playback audited.
- export governed.
- subject to legal, labor, contractual, and privacy review.

The design should minimize interactive secret entry through certificates, managed credentials, noninteractive automation, and controlled privilege elevation.

## Privilege elevation

Privilege elevation must be:

- Named.
- reason bound.
- time bounded where practical.
- separately logged.
- visible in the session recording.
- limited to required commands or roles where practical.
- revocable.

A general unrestricted root shell should be exceptional, not the routine maintenance path.

## Administrative capabilities

Approved administrators may:

- Inspect health and fault state.
- retrieve approved diagnostics.
- restart one failed workstation component.
- place a workstation component or console into visible maintenance.
- activate an approved signed release.
- roll back to an approved prior release.
- isolate the workstation.
- coordinate a reboot.
- rebuild the workstation through approved tooling.

They must not casually:

- inspect protected incident content without authorization.
- type into the operator session.
- attach silently to the operator display.
- install arbitrary Internet software.
- modify production binaries manually.
- perform untracked one-off package upgrades.
- disable logging or recording.
- clear fault diagnostic records.

## File transfer

Interactive session recording is not the preferred transport for large or binary files.

Use governed mechanisms for:

- signed release deployment.
- diagnostic bundle collection.
- configuration delivery.
- approved support artifacts.

Every transfer remains attributable, integrity checked, and recorded by metadata.

## Operator impact

Remote work that affects the operator is coordinated through the Managed Operational Console Session.

The operator sees states such as:

- Support connected.
- diagnostics being collected.
- workstation component maintenance scheduled.
- workstation component restarting.
- console reboot requested.
- console out of service.

The system must not imply that a remote administrator is viewing protected content when only system diagnostics are being accessed, or hide such viewing when it is occurring.

## Break glass

Break-glass access requires:

- Separately protected credentials.
- explicit activation.
- strong notification.
- short time bounds.
- full recording.
- off-host audit and diagnostic records.
- mandatory review.
- credential rotation or re-sealing after use.

## Failure behavior

If the authoritative recorder is unavailable:

- New interactive administration should normally be denied.
- emergency access follows break-glass policy.
- the condition is recorded by independent controls.
- existing sessions may be terminated according to policy.

Recording failure must not silently produce an unrecorded normal session.

## Session closure

At session end, record:

- Administrator disposition.
- actions completed.
- services or releases changed.
- unresolved issues.
- fault episode or ticket updates.
- validation result.
- whether operator impact occurred.
- whether follow-up is required.
