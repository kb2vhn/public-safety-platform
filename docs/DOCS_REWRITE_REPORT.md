# Documentation Rewrite Report

## Scope

This package replaces the complete current `docs/` tree and adds an `architecture/README.md` index.

## Consistency Changes

- Corrected the top-level documentation tree to match actual repository directories.
- Removed references to nonexistent current `foundation/`, `domains/`, and `decisions/` top-level documentation directories.
- Updated the renamed `control-implementation-and-assurance-artifact-model.md` reference.
- Added `two-person-concept.md` to the goals index.
- Standardized **assurance artifact** terminology to avoid conflict with the future Evidence and Property domain.
- Standardized the distinction between normative architecture and current implementation.
- Mapped Foundation documents to current migrations `000–099`.
- Documented the intentionally self-contained `sql/test-framework/` layout.
- Added current implementation limitations instead of implying completed enforcement.
- Standardized relative cross-links and section structure.
- Added accurate migration-range and manifest guidance.
- Added deployment-security reminders for ownership, off-host logs, backup protection, break-glass access, and trusted recovery.

## Files

The replacement tree is under `docs/`.

## Installation

From the repository root, back up the current documentation and copy the replacement:

```bash
mv docs docs.before-consistency-rewrite
cp -a /path/to/this-package/docs ./docs
```

Review the diff before committing:

```bash
git diff --no-index docs.before-consistency-rewrite docs
```

After review:

```bash
git add docs
git commit -m "rewrite documentation for Foundation consistency"
```
