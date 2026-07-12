# Network Communication Profile

> **Status:** Draft normative architecture.
>
> **Implementation status:** Policy model proposed; production endpoints and rules not yet selected.

## Purpose

Every Operational Workstation must have a documented and enforceable communication profile. A connection is permitted only because a current workflow or control requires it.

## Enforcement model

- Host firewall deny by default.
- Upstream network segmentation and access control provide an independent boundary.
- No unrestricted Internet access during normal production operation.
- Inbound access is denied except for explicitly approved management paths.
- Egress to external providers, when unavoidable, uses approved destinations or a controlled egress proxy or gateway.
- DNS, time, certificate, update, logging, EDR, and management dependencies are included explicitly.

A host firewall may not reliably authorize traffic by arbitrary user-space process identity. The source process remains required governance and telemetry metadata, while enforcement should use stable interfaces, destinations, ports, service identities, proxies, namespaces, or other controls selected by deployment architecture.

## Communication record

Each path must record:

- Stable rule identifier.
- Source component and executable or service identity.
- Direction.
- Source interface or network zone.
- Destination service and governed address set.
- Protocol and port.
- DNS dependency.
- Authentication and encryption.
- Data classification.
- Expected frequency, session duration, and bandwidth.
- Failure and degraded behavior.
- Logging and alert requirements.
- Owner, approval state, expiry, and last review date.

## Expected service categories

A production profile may require bounded access to:

- Authentication, session, and authorization services.
- Subscription and live-update gateway.
- Map and GIS publication services.
- Internal DNS and approved time service.
- PKI, revocation, and trust-evidence services.
- Off-host logging and health collectors.
- EDR or endpoint-security service endpoints.
- Internal update and configuration repositories.
- Snapshot or backup coordination services where applicable.
- Approved remote-management bastions and automation controllers.

## SSH boundary

Inbound SSH must be allowed only from approved management hosts or networks and must follow the [Remote Management Model](remote-management-model.md).

## Drift detection

The platform must detect unexpected:

- Outbound destinations.
- Listening sockets.
- Firewall changes.
- Routes and resolvers.
- Interfaces, wireless radios, and VPNs.
- Local proxies and tunnels.
- Repository configuration.

See [network-communications.example.yaml](examples/network-communications.example.yaml).
