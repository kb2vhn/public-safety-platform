# Phase 6 Step 7 Linux Process, Transport, and Delivery-Worker Deployment Boundary

> **Status:** Step 6 authenticated transport checkpoint accepted; Step 7
> integration and monitoring delivery-worker configuration is an implementation
> candidate. These files are not production installation approval.

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
├── foundation-api.transport-hmac-key.cred
├── integration-delivery-worker.database-url.cred
├── integration-delivery-worker.delivery-token.cred
├── monitoring-delivery-worker.database-url.cred
└── monitoring-delivery-worker.delivery-token.cred
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

Each service unit uses one distinct encrypted database credential source and
exposes it to the process under the short name `database-url` through:

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


## Step 6 Foundation API transport credential

Only `iron-signal-foundation-api.service` receives:

```text
LoadCredentialEncrypted=transport-hmac-key:/etc/iron-signal-platform/credentials/foundation-api.transport-hmac-key.cred
ISSP_TRANSPORT_HMAC_KEY_FILE=%d/transport-hmac-key
ISSP_BUSINESS_LISTEN_ADDRESS=127.0.0.1:18080
ISSP_TRANSPORT_MAX_CONCURRENT_REQUESTS=8
```

The worker units receive none of these settings. The business listener is
separate from the administrative port and remains loopback-only.


## Step 7 delivery-worker relay credentials

Each worker unit additionally receives one distinct encrypted `delivery-token`
credential and a fixed deployment-owned relay endpoint. The repository unit
uses an `.invalid` documentation endpoint so a deployment must replace it with
a governed HTTPS relay before operational use.

```text
LoadCredentialEncrypted=delivery-token:<service-specific-source>
ISSP_DELIVERY_TOKEN_FILE=%d/delivery-token
ISSP_DELIVERY_ENDPOINT=https://<governed-relay>/v1/deliveries
ISSP_DELIVERY_BATCH_SIZE=8
ISSP_DELIVERY_MAX_CONCURRENT=4
ISSP_DELIVERY_CLAIM_LEASE=30s
ISSP_DELIVERY_POLL_INTERVAL=1s
ISSP_DELIVERY_REQUEST_TIMEOUT=5s
ISSP_DELIVERY_RETRY_INITIAL=5s
ISSP_DELIVERY_RETRY_MAXIMUM=5m
```

The workers do not use database destination fields as network addresses. Relay
credentials, endpoints, payloads, response bodies, and durable identifiers are
excluded from logs.
