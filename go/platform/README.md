# Iron Signal Platform Production Go Module

> **Phase status:** Phase 6 Step 2 workspace and reproducible-build baseline.
>
> **Runtime status:** Executable skeletons only. No listener, database pool,
> credential loading, protected operation, worker claim loop, or production
> deployment is implemented.

## Module

```text
github.com/Iron-Signal-Systems/iron-signal-platform/go/platform
```

The module requires Go 1.26 semantics and pins the validated toolchain to
`go1.26.5`. Validation uses `GOTOOLCHAIN=local`; the development and build host
must therefore provide the exact accepted toolchain instead of downloading a
replacement implicitly.

## Executables

```text
cmd/foundation-api
cmd/integration-delivery-worker
cmd/monitoring-delivery-worker
```

Each executable is bound to one accepted Phase 5 PostgreSQL service identity.
At Step 2, every executable exits with status 78 and an explicit message that
runtime bootstrap is not implemented.

## Commands

From this directory:

```bash
./scripts/check.sh
./scripts/build.sh
```

`check.sh` verifies formatting, package tests, vetting, module tidiness, the
zero-third-party dependency baseline, bounded skeleton behavior, and two-build
binary reproducibility.

`build.sh` creates static, trimmed Linux artifacts and a deterministic build
manifest under `dist/` unless another output directory is supplied.

## Boundary

This module must not import `go/experiments/`. Step 2 does not connect to
PostgreSQL, open a network or Unix-domain listener, load secrets, run
migrations, or execute protected Foundation routines.

The canonical Arch compiler build validated by this baseline is `go1.26.5-X:nodwarf5`. The repository `TOOLCHAIN` file preserves that complete build identity.
