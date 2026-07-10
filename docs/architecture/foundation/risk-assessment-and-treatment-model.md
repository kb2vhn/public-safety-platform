# Platform Risk Assessment and Treatment Model

## Purpose

This document defines reusable risk identification, analysis, treatment, acceptance, review, and historical preservation.

## Risk Record

A Risk Record should include:

- Stable risk identifier
- Title
- Description
- Threat
- Vulnerability
- Affected assets and services
- Organization and jurisdiction scope
- Data classification
- Likelihood
- Impact
- Inherent risk
- Existing controls
- Residual risk
- Risk owner
- Treatment decision
- Review date
- Effective period
- Status
- Supporting evidence
- Policy version
- Decision Records

## Treatment Options

```text
MITIGATE
AVOID
TRANSFER
ACCEPT
DEFER
ESCALATE
```

## Risk Acceptance

Risk acceptance must be:

- Explicit
- Attributable
- Authorized by policy
- Scoped
- Time-bounded
- Supported by rationale
- Linked to affected controls and findings
- Reviewed before expiration
- Unable to conceal mandatory legal obligations

## Risk Assessment Lifecycle

Possible states include:

```text
IDENTIFIED
UNDER_ANALYSIS
TREATMENT_PLANNED
TREATMENT_IN_PROGRESS
ACCEPTED
MONITORED
ESCALATED
CLOSED
SUPERSEDED
```

## Reassessment Triggers

Reassessment may be required by:

- Material software change
- New provider
- New data classification
- New organization participation
- Policy or regulatory change
- Security incident
- Significant finding
- Architecture change
- New threat intelligence
- Expired evidence
- Control failure

## Architectural Invariants

1. Risk acceptance is not silent noncompliance.
2. Risk owners and accepting authorities remain distinct when policy requires.
3. Acceptance is scoped and expires.
4. Regulatory prohibitions cannot be waived by ordinary risk acceptance.
5. Risk history remains immutable.
6. Every treatment and acceptance decision creates a Decision Record.
