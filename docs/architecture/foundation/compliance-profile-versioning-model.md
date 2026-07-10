# Platform Compliance Profile Versioning Model

## Purpose

This document defines how external and internal requirements are mapped into versioned compliance profiles.

## Compliance Profile

A profile represents a defined set of requirements for a scope.

Examples may include:

- CJIS Security Policy profile
- HIPAA Security Rule profile
- IRS Publication 1075 profile
- PCI DSS profile
- State records profile
- Local policy profile
- Contractual security profile

## Profile Contents

A profile should include:

- Stable profile identifier
- Title
- Issuing authority
- Source framework
- Source version or publication date
- Internal version
- Approval date
- Effective period
- Applicable scope
- Requirement mappings
- Required control versions
- Evidence requirements
- Assessment frequency
- Exceptions policy
- Transition rules
- Integrity hash
- Decision Record

## Requirement Mapping

Each profile requirement maps:

```text
External Requirement
        ↓
Internal Profile Requirement
        ↓
Common Control or Control Enhancement
        ↓
Required Implementation
        ↓
Required Evidence
        ↓
Assessment Procedure
```

## Multiple Profiles

A service may be subject to multiple profiles.

The effective requirement set is normally the union of all applicable obligations, with conflicts resolved through explicit legal, policy, and Data Owner review.

## Version Changes

When an external framework changes, the platform must preserve:

- Previous source version
- New source version
- Changed requirements
- Transition date
- Grace period where legally permitted
- Affected controls
- Affected implementations
- Reassessment requirements
- Historical decisions

## Profile Activation

A profile version must not become active without:

- Verified source reference
- Internal review
- Approval
- Effective date
- Scope
- Integrity metadata

## Architectural Invariants

1. Compliance profiles are separate from Foundation control mechanics.
2. Every profile is versioned and effective-dated.
3. Requirement mappings are explicit.
4. Multiple profiles may apply simultaneously.
5. Missing required mappings fail safely.
6. Historical assessments use historical profile versions.
7. Current profiles do not rewrite prior compliance determinations.
