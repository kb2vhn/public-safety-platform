# Network Communication Profile

> Status: Normative target architecture.
>
> Implementation status: Policy model defined; production endpoints and rules are not yet selected.

## Purpose

Every Operational Workstation must have a documented and enforceable communication profile.

A connection is permitted only because a current workflow, dependency, support function, or control requires it.

## Enforcement model

- Host firewall denies by default.
- Upstream network segmentation and access control provide an independent boundary.
- Normal production operation has no unrestricted Internet access.
- Inbound access is denied except for approved management and required local paths.
- External-provider access, where unavoidable, uses approved gateways, proxies, or destination sets.
- DNS, time, certificate, update, logging, endpoint security, management, and recovery dependencies are explicit.
- Renderer processes are denied direct remote application-content access.
- Module services receive only their approved destination profile.
- Loopback and Unix-domain socket communication are governed, not assumed safe.

## Communication record

Each approved communication declares:

- Rule identifier.
- owning service or module.
- local identity or systemd unit.
- direction.
- protocol.
- local address and port where relevant.
- remote service identity.
- remote address or destination set.
- DNS dependency.
- certificate or mutual-authentication requirement.
- expected session duration.
- expected request rate and bandwidth.
- data classification.
- operational purpose.
- failure effect.
- monitoring and alerting.
- approval.
- review date.
- expiration or permanent status.
- related release and profile version.

## Remote application communication

Only controlled native services may communicate with remote platform services.

A renderer must not receive:

- Platform endpoint topology.
- private client credentials.
- device private keys.
- unrestricted remote URL capability.
- generic proxy capability.

The native service validates remote identity and presents a narrow local contract.

## Local IPC

Unix-domain sockets are governed by the local IPC model.

Host firewall rules do not replace:

- Filesystem permissions.
- peer credential checks.
- module instance authentication.
- message authorization.
- rate and size limits.
- replay controls.

## Loopback

Loopback TCP may be approved for a documented compatibility requirement.

Where used:

- Bind one exact loopback address.
- prohibit wildcard binding.
- define IPv4 and IPv6 behavior.
- authenticate the local client.
- restrict the expected host value.
- apply application-layer authorization.
- prevent generic proxying.
- log unexpected access.
- include the rule in baseline and drift checks.

Use of an address such as `127.9.1.1` may aid organization but does not establish identity.

## Inbound management

SSH is permitted only from approved:

- Bastions.
- automation controllers.
- management networks.
- recovery networks under governed activation.

The operator network and general user networks must not reach SSH.

The final profile should bind `sshd` only to approved management addresses or interfaces where practical.

## Updates

Production consoles retrieve only:

- Signed release metadata.
- approved package or image artifacts.
- revocation information.
- approved emergency update data.

They do not browse public package repositories directly during normal operation.

Daily and Pre-production environments may have different controlled access profiles.

## Logging and telemetry

Logs and fault events must be exported off-host.

The profile defines:

- destination.
- transport security.
- buffering.
- retry.
- bandwidth ceiling.
- classification.
- behavior when the collector is unavailable.
- retention of unsent critical evidence.
- protection against log-induced resource exhaustion.

## DNS

DNS dependencies are minimized and explicit.

A rule based on a hostname must define:

- Approved resolver.
- expected domain.
- resolution freshness.
- failure behavior.
- protection against unexpected addresses.
- whether certificate identity remains authoritative.

DNS success alone does not establish remote trust.

## Network time

Time synchronization uses approved sources and authentication where supported.

Time failure or excessive skew becomes health and trust evidence.

## External systems

Radio, telephony, recording, alerting, mapping, and other integrations use governed adapters.

The workstation should normally communicate with platform-managed adapters rather than directly with vendor systems.

Any direct exception declares:

- Why an adapter is not used.
- credentials and trust anchors.
- vendor availability behavior.
- data ownership.
- recording and audit.
- replacement path.
- expiration or review date.

## Denied communications

The profile should detect and report:

- Unexpected listening sockets.
- unexpected remote destinations.
- renderer remote connection attempts.
- unauthorized DNS.
- wildcard listeners.
- peer-to-peer discovery.
- consumer telemetry.
- package-manager public repository access.
- unauthorized remote administration.
- unapproved local loopback services.

## Validation

Validation includes:

- Rule generation.
- rule application.
- positive required-flow tests.
- negative prohibited-flow tests.
- restart persistence.
- IPv4 and IPv6 tests.
- renderer escape tests.
- local pivot tests.
- upstream segmentation tests.
- behavior during logging, DNS, time, and update failure.
