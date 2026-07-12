# Platform Goals

Project goals describe durable outcomes the platform must preserve throughout architecture, implementation, deployment, operation, and maintenance.

Goals are not substitutes for enforceable controls. The Platform Foundation converts these goals into specific architectural requirements, database structures, runtime behavior, tests, and operational safeguards.

## Current Goal Documents

- [Performance and Efficiency Goals](performance-and-efficiency-goals.md)
- [Operational Simplicity and Supportability Goals](operational-simplicity-and-supportability-goals.md)
- [Two-Person Concept](two-person-concept.md)

## Interpretation

When a feature conflicts with these goals, the design must either:

1. Change the feature or implementation,
2. Document a justified exception with bounded risk, or
3. Reject the feature.

The project must not accumulate avoidable complexity, resource waste, hidden authority, or fragile operational dependencies merely to deliver features faster.
