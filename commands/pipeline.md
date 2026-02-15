---
description: "Show the requirements pipeline stages in order"
---

You are a requirements engineering guide. Print the following pipeline overview exactly as shown, then stop. Do not execute any commands or read any files.

## Requirements Engineering Pipeline

Run these commands in order. Each stage builds on artifacts from previous stages, but can also run standalone if the prerequisite artifacts already exist.

| Stage | Command | Output | Prerequisites |
|-------|---------|--------|---------------|
| 1 | `/ddd-analysis {source-dir}` | `docs/ddd-analysis.md` | Source code access |
| 2 | `/analyze-codebase {source-dir}` | `docs/codebase-analysis/reading-order.md` | (optional: DDD analysis present → skips domain model discovery, enriches annotations) |
| 3 | `/extract-requirements {reading-order-or-source-path}` | `docs/requirements/business-requirements.md`, `docs/requirements/technical-requirements.md` | Reading order guide, source directory, or empty for auto-discovery (optional: DDD analysis enriches output) |
| 3b | `/extract-flows {requirements-dir}` | `docs/requirements/flow-catalog.md` | Project-specific business + technical requirements (required); DDD analysis (optional, enriches output) |
| 4 | `/generalize-requirements {requirements-dir}` | `docs/generalized-requirements/*.md` | Business + technical requirements (required); original DDD analysis (optional, for terminology) |
| 4b | `/generalize-ddd-analysis {requirements-dir}` | `docs/generalized-requirements/ddd-analysis.md` | Original DDD analysis + generalized business requirements + generalized technical requirements (all required) |
| 4c | `/generalize-flows {requirements-dir}` | `docs/generalized-requirements/flow-catalog.md` | Project-specific flow catalog + generalized business requirements + generalized technical requirements (all required); generalized DDD analysis (optional, for terminology cross-reference) |
| 5 | `/decompose-services {requirements-dir}` | `docs/generalized-requirements/service-decomposition.md` | Generalized requirements (required); generalized DDD analysis (optional, preferred) or original DDD analysis (optional, fallback); generalized flow catalog (optional, informs boundary decisions) |
| 6 | `/generate-jira-tasks {requirements-dir}` | `docs/generalized-requirements/jira-tasks.*.md`, `docs/generalized-requirements/technical-requirements.observability-and-testing.md`, `docs/generalized-requirements/jira-checklist.observability.md` | Generalized requirements (required); service decomposition (recommended, warns and proceeds without); generalized DDD analysis (optional); generalized flow catalog (optional, enriches acceptance criteria) |
| 7 | `/review-requirements {requirements-dir}` | `docs/generalized-requirements/review-findings.md` + fixes applied to all documents | Business requirements + technical requirements + Jira task files (required); DDD analysis + service decomposition + flow catalog (optional) |

### Quick Start (typical invocation)

```
/ddd-analysis src/
/analyze-codebase src/
/extract-requirements docs/codebase-analysis/reading-order.md
/extract-flows docs/requirements/
/generalize-requirements docs/requirements/
/generalize-ddd-analysis docs/generalized-requirements/
/generalize-flows docs/generalized-requirements/
/decompose-services docs/generalized-requirements/
/generate-jira-tasks docs/generalized-requirements/
/review-requirements docs/generalized-requirements/
```

### Notes

- **Stage 1 (DDD analysis)** is the foundation. Stages 2-3 check for `docs/ddd-analysis.md`. Stages 5-7 prefer the generalized version (`docs/generalized-requirements/ddd-analysis.md`) if Stage 4b was run, falling back to the original.
- **Stages 1-3** extract what IS in the code. **Stage 3b** catalogs behavioral flows from the project-specific requirements. **Stages 4-4c** generalize. **Stage 5** decomposes. **Stage 6** creates actionable tasks. **Stage 7** validates consistency.
- **Stage 4b** is optional but recommended — it ensures the generalized DDD analysis uses the same terminology as all downstream documents, eliminating terminology divergence noise in Stage 7 reviews.
- You can skip stages if artifacts already exist (e.g., skip to Stage 6 if you already have generalized requirements).
- Stage 7 is idempotent — run it after any changes to verify consistency.
- **Re-running stages**: After modifying a document, re-run all downstream stages that consume it (see the Prerequisites column for dependencies). Stage 7 should always be the final step after any re-run. If the output file already exists, it will be overwritten — ensure downstream documents are re-generated as well. Stage 7 additionally modifies all reviewed documents when applying fixes — ensure you're comfortable with those changes before re-running. Notable re-run: Stage 4b can be re-run after Stage 5 to cross-reference the generalized DDD analysis with the service decomposition decisions (see Stage 4b's Phase 3).
- **Agent Teams**: Stages 1-3 and 6-7 support optional parallelization via agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Stages 3b, 4, 4b, 4c, and 5 are sequential-only (single synthesized output).
- **These pipeline commands are for requirements engineering.** For general development tasks (bug fixes, features, refactoring), use `/create-prompt` or `/create-meta-prompt` instead.
