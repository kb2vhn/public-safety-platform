# User-Interface Architecture

> Status: Normative architecture under active refinement.

## Purpose

This directory defines cross-platform requirements for human-facing
interfaces.

These requirements apply to shared interface components, module interfaces,
public portals, administrative applications, operational workstations,
mobile applications, and generated human-readable content.

User-interface architecture may consume services and governance structures
provided by the Platform Foundation. It must not place interface-specific
concepts or presentation behavior inside the domain-neutral Foundation.

## Dependency Direction

```text
Platform Foundation
        ↓
Shared Resources and Platform Services
        ↓
Module Families
        ↓
User Interfaces
