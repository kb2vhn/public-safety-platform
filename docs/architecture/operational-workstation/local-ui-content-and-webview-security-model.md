# Local UI Content and WebView Security Model

> Status: Normative target architecture.
>
> Implementation status: GTK 4 and WebKitGTK 6.0 are the initial reference direction; no production renderer profile is yet accepted.

## Purpose

This document defines how HTML, CSS, JavaScript, icons, fonts, map presentation resources, and other UI assets are supplied to console renderers without giving the renderer a direct path to remote operational content.

## Reference direction

The initial reference direction is:

- GTK 4 for native window integration.
- WebKitGTK 6.0 for standards-based rendering.
- Go for native module hosts and local services.
- Application-registered custom URI schemes for approved UI resources.
- A narrow native message bridge for renderer-to-host communication.
- Authenticated Unix-domain sockets for host-to-service communication.

Uzbl or another general-purpose browser shell is not the reference design. The console should embed the rendering engine directly so unnecessary browser functions are absent rather than hidden.

## Core rule

The renderer must not retrieve operational application content directly from a remote server.

The following path is prohibited for production application behavior:

```text
WebKit renderer
        │
        └── direct HTTPS request to remote platform or provider
```

The required path is:

```text
Remote platform or approved provider
        │
        ▼
Controlled Go service
        │
        ▼
Authenticated local IPC
        │
        ▼
Native module host
        │
        ▼
Narrow renderer bridge or custom URI response
        │
        ▼
WebKitGTK renderer
```

## Custom URI schemes

UI assets should be exposed through application-owned schemes such as:

```text
iron-console://shell/index.html
iron-incident://ui/index.html
iron-map://ui/index.html
iron-resources://ui/index.html
```

The scheme handler may serve resources from:

- Assets embedded into a verified binary.
- A read-only verified release directory.
- An in-memory generated response.
- A tightly controlled local module source.

The handler must not become a generic file server or arbitrary path resolver.

## Release-controlled resources

Every served UI asset must be associated with:

- Console release identifier.
- Module release identifier.
- Path or logical resource identifier.
- Cryptographic digest.
- Content type.
- size limit.
- cache policy.
- security classification where applicable.

Resources must be verified before use or verified as part of the signed release activation process.

The renderer must not load resources from an operator-writable directory.

## Navigation policy

The native host must deny navigation except to explicitly approved schemes and destinations.

At minimum, it must block or govern:

- `http:`
- `https:`
- `file:`
- `ftp:`
- `data:` where not explicitly required
- `blob:` where not explicitly required
- `javascript:` navigation
- external application launch
- arbitrary new windows
- popups
- downloads
- file chooser access
- protocol handlers
- clipboard formats outside policy
- drag-and-drop from unmanaged sources

Attempts are recorded as security or diagnostic events.

## Remote network denial

Defense in depth must prevent the renderer and its helper processes from initiating ordinary remote network connections.

Controls may include:

- systemd service network restrictions.
- separate Linux identities.
- network namespaces.
- host firewall process or cgroup controls where supported.
- WebKit policy callbacks.
- disabled proxy configuration.
- absence of remote server addresses and credentials.
- strict content security policy.
- no general DNS requirement for renderer processes.

The final implementation must be tested for direct and indirect network escape paths.

## Native message bridge

Renderer messages must pass through a narrow, versioned API.

The bridge must not expose:

- arbitrary Go method invocation.
- arbitrary filesystem access.
- shell execution.
- raw database access.
- unrestricted local socket access.
- platform credentials.
- device private keys.
- administrative tokens.
- generic HTTP proxying.
- dynamic native library loading.

Every bridge method defines:

- Request schema.
- response schema.
- maximum size.
- timeout.
- allowed call rate.
- required renderer origin.
- required module state.
- error behavior.
- audit or diagnostic requirement.
- whether the method can cause a protected platform action.

## Renderer compromise assumption

The architecture must assume that renderer content or the rendering engine could be compromised.

A compromised renderer should still be unable to:

- read platform credentials.
- connect directly to platform servers.
- perform arbitrary protected actions.
- impersonate another module.
- modify the signed release.
- read another operator's cached state.
- access unrestricted local files.
- silently suppress the global degraded-state surface.
- modify remote-management controls.

## Storage

Web storage, cookies, IndexedDB, caches, service workers, and other persistent renderer storage are disabled unless a specific module profile approves them.

Where approved, the profile defines:

- Purpose.
- maximum size.
- operator or workstation scope.
- encryption and isolation.
- retention.
- purge behavior.
- migration behavior.
- backup prohibition or permission.
- behavior after abnormal termination.

Service workers must not introduce an uncontrolled second update or cache mechanism.

## Content security policy

Each module uses a restrictive Content Security Policy.

The default intent is:

- no remote scripts.
- no remote styles.
- no remote images.
- no remote fonts.
- no inline script unless cryptographically constrained and reviewed.
- no `eval` or equivalent dynamic code generation.
- no framing by unapproved origins.
- no uncontrolled form submission.
- no mixed content.
- no browser extension dependency.

Exceptions require documented risk acceptance and test evidence.

## Local HTTP exception

A loopback HTTP service may be approved where a required library cannot operate through a custom URI scheme or local bridge.

Any exception must:

- Bind to one exact loopback address.
- Never bind to `0.0.0.0` or an external interface.
- Address IPv4 and IPv6 behavior explicitly.
- authenticate the client with a per-start capability.
- validate the expected host value.
- expose no proxy or arbitrary file function.
- use restrictive CORS and CSP.
- have a documented firewall rule.
- be included in the communication profile.
- be removed when the dependency no longer requires it.

A distinct loopback address organizes traffic; it does not authenticate the connecting process.

## Accessibility

Custom rendering must preserve support for:

- Keyboard navigation.
- predictable focus.
- screen-reader semantics.
- magnification and scaling.
- high contrast.
- reduced motion where required.
- alternate input.
- visible status not dependent on color alone.

A custom-drawn surface that bypasses accessible semantic structures requires equivalent validated accessibility behavior.
