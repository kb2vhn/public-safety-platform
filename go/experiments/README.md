# Go Experiments

This directory contains exploratory Go code created while evaluating possible implementation approaches for the Public Safety Platform.

The code in this directory is **not production code** and does not represent the current Platform Foundation architecture, security model, database contract, or planned backend design.

## Purpose

The experiments are retained as historical reference for ideas that were explored before the Foundation documentation and PostgreSQL trust model were established.

They may demonstrate early concepts related to:

* Authentication
* LDAP and LDAPS connectivity
* Configuration handling
* Credential processing
* Cryptographic utilities
* Backend package organization

These experiments may be incomplete, insecure, incorrect, or incompatible with the current platform design.

## Important Restrictions

Code under this directory must not be:

* Deployed to a production environment
* Imported by production platform packages
* Used as the basis for security decisions
* Treated as a supported authentication implementation
* Used to store or process real credentials
* Considered compliant with the current audit, authorization, or trust model

Any credentials, keys, certificates, usernames, hostnames, or encrypted values contained in the experiments are examples only and must not be reused.

## Future Implementation

The production Go backend will be designed separately after the Platform Foundation documentation and SQL migrations have reached a stable and validated state.

The future implementation will be built around:

* Defined PostgreSQL security boundaries
* Controlled database APIs
* Explicit identity and trust assertions
* Authorization leases
* Decision records
* Structured audit events
* Secure secrets management
* Timeouts and cancellation
* Consistent error handling
* Automated testing
* Deployment and operational security requirements

Code in this directory may be rewritten completely or removed without notice.

## Current Status

**Status: Historical prototype and experimentation only**

Nothing under `go/experiments` should be considered part of the supported Public Safety Platform runtime.

