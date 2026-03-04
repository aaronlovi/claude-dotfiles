# Plan: Pipeline Output to Obsidian Vault with Second Brain Ingestion

## Context
- Research: `.prompts/pipeline-obsidian-output-research/research.md`
- Guidelines: `CLAUDE.md`

## Prior Knowledge
- The ingest script (`~/.claude/scripts/second-brain/ingest.py`) requires no modifications — it already handles arbitrary base paths and uses filename-based doc type detection and path-based specificity detection.
- `~/.claude/.env` contains `OBSIDIAN_VAULT=/mnt/c/Users/aaron/ObsidianVaults/DevNotes` — all commands must read this at runtime, not hardcode the path.
- Project name is derived via `basename $(git rev-parse --show-toplevel)`.
- Output directory structure: `$OBSIDIAN_VAULT/Pipeline/{project-name}/` preserving the existing `requirements/`, `generalized-requirements/`, and `codebase-analysis/` subdirectory layout.

## Instructions
1. Read `.prompts/pipeline-obsidian-output-research/research.md`
2. Design implementation as checkpoints
3. Each checkpoint must include:
   - Build: what to implement
   - Test: how to verify this checkpoint's changes work correctly (manual verification is acceptable for prompt/markdown-only changes — describe the specific checks to perform)
   - Verify: how to confirm everything is consistent before moving on
4. NEVER design a dedicated "testing" checkpoint at the end. Verification is done within each checkpoint.

## Scope

### What changes

All 10 pipeline command prompts in `commands/` need two modifications each:
1. **Output paths**: Replace `docs/...` output paths with vault-based paths (`$OBSIDIAN_VAULT/Pipeline/{project-name}/...`)
2. **Input paths (Prerequisites)**: Replace `docs/...` input paths that reference upstream artifacts with vault-based paths

Additionally:
3. **`commands/pipeline.md`**: Update the pipeline table (Output column, Quick Start examples, Notes section) and add Stage 8
4. **New command**: Create `commands/ingest-second-brain.md`
5. **`skills/prompt-rules/SKILL.md`**: Update the note about pipeline output conventions (line 34 mentions `docs/`)

### What does NOT change
- `~/.claude/scripts/second-brain/ingest.py` — works as-is
- Source code input paths (`$ARGUMENTS` for source directories like `src/`) — these stay relative to CWD
- The `.prompts/` directory structure and conventions
- Relative markdown cross-references within generated documents (directory structure is preserved)

### Pattern for each command

Each command needs an **Output Location** section added after the Input/Prerequisites sections:

```markdown
## Output Location

Before writing any output, determine the output base directory:

1. Read `~/.claude/.env` to get the `OBSIDIAN_VAULT` path.
2. Derive the project name: `basename $(git rev-parse --show-toplevel)`
3. Set output base: `$OBSIDIAN_VAULT/Pipeline/{project-name}/`
4. Create the output directory with `mkdir -p` if it doesn't exist.

All output paths in this command are relative to this base directory.
```

Then replace every `docs/...` reference (both output and input) with `{output-base}/...` equivalent.

### Commands and their path changes

| Command | Output paths to change | Input paths to change |
|---------|----------------------|----------------------|
| `ddd-analysis.md` | `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md` | None (first stage) |
| `analyze-codebase.md` | `docs/codebase-analysis/reading-order.md` → `{output-base}/codebase-analysis/reading-order.md` | `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md` |
| `extract-requirements.md` | `docs/requirements/*.md` → `{output-base}/requirements/*.md` | `docs/codebase-analysis/reading-order.md`, `docs/ddd-analysis.md` |
| `extract-flows.md` | `docs/requirements/flow-catalog.md` → `{output-base}/requirements/flow-catalog.md` | `docs/requirements/` directory |
| `generalize-requirements.md` | `docs/generalized-requirements/*.md` → `{output-base}/generalized-requirements/*.md` | `docs/requirements/`, `docs/ddd-analysis.md` |
| `generalize-ddd-analysis.md` | `docs/generalized-requirements/ddd-analysis.md` → `{output-base}/generalized-requirements/ddd-analysis.md` | `docs/ddd-analysis.md`, `docs/generalized-requirements/` |
| `generalize-flows.md` | `docs/generalized-requirements/flow-catalog.md` → `{output-base}/generalized-requirements/flow-catalog.md` | `docs/requirements/flow-catalog.md`, `docs/generalized-requirements/` |
| `decompose-services.md` | `docs/generalized-requirements/service-decomposition.md` → `{output-base}/generalized-requirements/service-decomposition.md` | `docs/generalized-requirements/`, `docs/generalized-requirements/ddd-analysis.md`, `docs/ddd-analysis.md` |
| `generate-jira-tasks.md` | `docs/generalized-requirements/jira-tasks.*.md`, `docs/generalized-requirements/technical-requirements.observability-and-testing.md`, `docs/generalized-requirements/jira-checklist.observability.md` | `docs/generalized-requirements/`, `docs/generalized-requirements/ddd-analysis.md`, `docs/ddd-analysis.md` |
| `review-requirements.md` | `docs/generalized-requirements/review-findings.md` | `docs/generalized-requirements/`, `docs/requirements/`, `docs/ddd-analysis.md` |

## Output
Write plan to `.prompts/pipeline-obsidian-output-plan/plan.md`:
- Ordered checkpoints (implementation + verification each)
- Files to create/modify
- Metadata block (Status, Dependencies, Open Questions, Assumptions)

<!-- Self-review: converged after 1 pass -->
