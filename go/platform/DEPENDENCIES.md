# Production Go Dependency Baseline

> **Phase status:** Phase 6 Step 2 dependency baseline.

The production Go module begins with **zero third-party runtime or build
modules**. `go list -m all` must return only:

```text
github.com/Iron-Signal-Systems/iron-signal-platform/go/platform
```

The initial executable skeletons and internal packages use only the Go standard
library. Consequently, Step 2 intentionally creates no `go.sum` file.

A future dependency may be added only through a reviewed change that records:

- the exact module path and pinned version;
- the bounded purpose for which it is required;
- why the standard library is insufficient;
- license and vulnerability disposition;
- transitive dependency impact;
- removal and upgrade strategy;
- confirmation that it does not broaden database, transport, secret, or host
  authority.

Production packages must not import code under `go/experiments/`.
