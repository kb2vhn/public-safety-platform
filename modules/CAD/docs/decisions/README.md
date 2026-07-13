# CAD Architecture Decisions

> **Status:** Decision structure established; no CAD migration range allocated

## Purpose

## Terminology Boundary

Files in this directory are Architecture Decision Records (ADRs). They document
why the CAD architecture was designed a particular way.

They are not Foundation **Decision Records**, do not represent an Authorization
Decision, and do not grant authority to perform a protected CAD operation.


Retain material CAD decisions so later implementation can explain why a
boundary, term, invariant, technology, range, or operational rule exists.

## Current Decisions

- [0001 — CAD Module Name and Repository Boundary](0001-cad-module-name-and-repository-boundary.md)
- [0002 — CAD User Interface and Operational Workstation Ownership](0002-cad-user-interface-and-operational-workstation-ownership.md)

## Planned Decisions

Future decisions are expected for CAD terminology, migration-range allocation,
schema and manifest names, incident-number allocation, operational event and
projection strategy, unit and resource identity, integration outbox and adapter
contracts, production Go service topology, dispatcher workstation delivery,
degraded authority, retention, and pilot deployment.

A planned decision is not an accepted decision.
