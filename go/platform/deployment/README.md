# Phase 6 Step 4 Linux Process-Host Deployment Boundary

> **Status:** Implementation candidate. These files are not production
> installation approval.

## Layout

The candidate installation layout is:

```text
/usr/lib/iron-signal-platform/
├── foundation-api
├── integration-delivery-worker
└── monitoring-delivery-worker

/usr/lib/systemd/system/
├── iron-signal-foundation-api.service
├── iron-signal-integration-delivery-worker.service
└── iron-signal-monitoring-delivery-worker.service

/usr/lib/sysusers.d/
└── iron-signal-platform.conf

/etc/iron-signal-platform/credentials/
├── foundation-api.database-url.cred
├── integration-delivery-worker.database-url.cred
└── monitoring-delivery-worker.database-url.cred
```

No plaintext credential or encrypted production credential is stored in this
repository.

## Service identities

The sysusers file creates three distinct non-login users and same-name groups:

```text
issp-foundation-api
issp-integration-delivery
issp-monitoring-delivery
```

No fixed numeric UID or GID is embedded in the package.

## Credential provisioning

Each service unit uses one distinct encrypted credential source and exposes it
to the process under the short name `database-url` through:

```text
LoadCredentialEncrypted=database-url:<service-specific-source>
ISSP_DATABASE_DSN_FILE=%d/database-url
```

An approved provisioning workflow may create the encrypted artifact with
`systemd-creds encrypt --name=database-url` using a protected ephemeral input
source. The PostgreSQL URL must not be placed on the command line, in shell
history, in a repository file, or in retained build output.

Host-key encryption is the minimum candidate boundary. A deployment may require
`host+tpm2` or another stronger accepted binding after host recovery and
replacement procedures are defined.

## Service behavior

All units:

- execute the compiled Go binary directly;
- use `Type=notify` and `NotifyAccess=main`;
- expose only a distinct literal-loopback administrative port;
- use bounded startup, shutdown, watchdog, restart, and start-rate controls;
- prevent restart after configuration exit 78;
- apply file-descriptor, task, memory, capability, namespace, filesystem,
  kernel, process, and address-family restrictions;
- create no writable persistent service state;
- define no socket-activation unit.

Remote PostgreSQL remains permitted. The base units therefore order after
`network-online.target` and do not name a distribution-specific PostgreSQL
service. A local-database deployment requires a governed site drop-in.

## Candidate validation

From `go/platform/`:

```bash
./scripts/test-process-host.sh
./scripts/test-process-host-runtime.sh
```

The first command validates Go race behavior, sysusers syntax, exact unit
directives, systemd unit syntax, offline hardening analysis, direct executable
hosting, distinct identities, credential separation, and absence of socket
activation.

The second command uses a disposable PostgreSQL 18 cluster, bounded local
blackhole listener, and Unix datagram notification receivers to prove
readiness, watchdog, stopping, database-unavailable no-readiness behavior,
startup cancellation, SIGINT and repeated termination, malformed environment,
occupied listeners, and disappeared notification sockets without invoking a
protected business operation.

The transport race tests separately prove bounded shutdown with an in-flight
administrative request and error propagation after an unexpected listener
closure.
