# Remote Management Model

> **Status:** Draft normative architecture.
>
> **Implementation status:** OpenSSH is the planned initial transport; final identity and bastion design is not yet implemented.

## Purpose

Operational Workstations require secure remote management for automation, investigation, recovery, and controlled maintenance.

OpenSSH is an approved initial management transport. It is not the management policy, authorization system, or configuration source of truth.

## Network boundary

- `sshd` listens only on approved management interfaces or addresses where practical.
- Host firewall rules allow inbound SSH only from approved automation controllers, bastions, or management networks.
- Arbitrary operator, user, and Internet-originated SSH is denied.
- Management traffic is logged and independently monitored.

## Authentication

- Password authentication disabled.
- Direct root login disabled.
- Public-key or SSH-certificate authentication required.
- Short-lived administrative credentials preferred.
- Administrative access should originate through a controlled bastion or equivalent approved path.
- MFA or independent administrative approval should be enforced at the management boundary where required.
- Shared long-lived private keys are prohibited.

## Session restrictions

Unless explicitly required and approved:

- Agent forwarding disabled.
- X11 forwarding disabled.
- TCP forwarding disabled.
- Gateway ports disabled.
- Unrestricted environment injection disabled.
- Unapproved file transfer disabled or separately controlled.

Administrative groups, allowed users, commands, source addresses, and privilege escalation must be explicit.

## Privilege and audit

- Normal automation uses least-privileged service identities.
- Interactive administration uses named identities.
- `sudo` privileges are command-scoped where practical.
- Privileged access is time-bounded and auditable.
- Commands, configuration changes, package changes, and file transfers produce off-host evidence.
- Break-glass access is separate, protected, tested, and reviewed after every use.

## Relationship to Ansible

Ansible or another declarative tool may use SSH as transport. The desired state remains in reviewed, version-controlled configuration. Repeated interactive shell repair must not become the normal management process.

## Failure behavior

Loss of SSH access must not prevent normal operator use. Loss of the management plane is a health condition requiring alerting and remediation, not an automatic reason to expose broader inbound access.
