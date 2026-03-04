# Plan: Pipeline Output to Obsidian Vault with Second Brain Ingestion

## Table of Contents

- [1. Overview](#1-overview)
- [2. Checkpoints](#2-checkpoints)
  - [2.1. Checkpoint 1 — Stage 1-2 Commands](#21-checkpoint-1--stage-1-2-commands)
  - [2.2. Checkpoint 2 — Stage 3-3b Commands](#22-checkpoint-2--stage-3-3b-commands)
  - [2.3. Checkpoint 3 — Stage 4-4c Commands](#23-checkpoint-3--stage-4-4c-commands)
  - [2.4. Checkpoint 4 — Stage 5-7 Commands](#24-checkpoint-4--stage-5-7-commands)
  - [2.5. Checkpoint 5 — Pipeline Table, Ingest Command, and Prompt Rules](#25-checkpoint-5--pipeline-table-ingest-command-and-prompt-rules)
- [3. Files to Create/Modify](#3-files-to-createmodify)
- [4. Metadata](#4-metadata)

---

## 1. Overview

Every pipeline command currently writes to `docs/` in the project's working directory. This plan changes all 10 commands + the pipeline table to write to and read from `$OBSIDIAN_VAULT/Pipeline/{project-name}/` instead, adds a new `/ingest-second-brain` command as Stage 8, and updates prompt-rules to reflect the new output convention.

**Shared pattern** — each command gets a new `## Output Location` section inserted after Prerequisites (or after Agent Teams Mode if present):

```markdown
## Output Location

Before writing any output, determine the output base directory:

1. Read `~/.claude/.env` to get the `OBSIDIAN_VAULT` path.
2. Derive the project name: `basename $(git rev-parse --show-toplevel)`
3. Set output base: `$OBSIDIAN_VAULT/Pipeline/{project-name}/`
4. Create the output directory with `mkdir -p` if it doesn't exist.

All output paths below are relative to this base directory (not the current working directory).
```

**Input path pattern** — Prerequisites sections that reference upstream artifacts change from `docs/...` to `{output-base}/...`, using the same resolution logic (read `~/.claude/.env`, derive project name).

**Source code paths are unchanged** — `$ARGUMENTS` for source directories (e.g., `src/`) stays relative to CWD.

---

## 2. Checkpoints

### 2.1. Checkpoint 1 — Stage 1-2 Commands

**Build**: Modify `commands/ddd-analysis.md` and `commands/analyze-codebase.md`.

For `ddd-analysis.md`:
- Insert the `## Output Location` section after the `## Agent Teams Mode` section (before `## Process`).
- In the Agent Teams Coordination section (line 38): change `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md`.
- In the Output Format section (line 191): change `Create the \`docs/\` directory if it doesn't exist, then write the output to \`docs/ddd-analysis.md\`` → `Create the output base directory if it doesn't exist, then write the output to \`{output-base}/ddd-analysis.md\``.
- In the Next step line (line 290): change `Run \`/analyze-codebase {source-dir}\`` — no path change needed (source-dir stays as-is).

For `analyze-codebase.md`:
- Insert the `## Output Location` section after the `## Agent Teams Mode` section (before `## Process`).
- In Prerequisites (line 16-19): change `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md` (3 occurrences in that section).
- In Agent Teams Coordination (line 42): change `docs/codebase-analysis/reading-order.md` → `{output-base}/codebase-analysis/reading-order.md`.
- In Output Format (line 98): change `Create the output directory (\`docs/codebase-analysis/\`)` → `Create the output directory (\`{output-base}/codebase-analysis/\`)` and `write to \`docs/codebase-analysis/reading-order.md\`` → `write to \`{output-base}/codebase-analysis/reading-order.md\``.
- Next step line (line 155): no path change needed (source-dir stays as-is).

**Verify**: Read both modified files from disk. Confirm:
- No remaining `docs/` references for output or input paths (grep for `docs/`).
- `$ARGUMENTS` / source-dir references are unchanged.
- The Output Location section is positioned correctly (after Agent Teams Mode, before Process).

---

### 2.2. Checkpoint 2 — Stage 3-3b Commands

**Build**: Modify `commands/extract-requirements.md` and `commands/extract-flows.md`.

For `extract-requirements.md`:
- Insert the `## Output Location` section after `## Agent Teams Mode` (before `## Process`).
- In Input section (lines 11-13): change `docs/codebase-analysis/reading-order.md` → `{output-base}/codebase-analysis/reading-order.md` and `docs/codebase-analysis/` → `{output-base}/codebase-analysis/`.
- In Prerequisites (lines 19-21): change `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md` and `docs/codebase-analysis/reading-order.md` → `{output-base}/codebase-analysis/reading-order.md`.
- In Output Format (lines 107-109): change `Create \`docs/requirements/\`` → `Create \`{output-base}/requirements/\``, `docs/requirements/business-requirements.md` → `{output-base}/requirements/business-requirements.md`, `docs/requirements/technical-requirements.md` → `{output-base}/requirements/technical-requirements.md`.
- In Next step (line 186): change `docs/requirements/` → `{output-base}/requirements/` in the example invocations.

For `extract-flows.md`:
- Insert the `## Output Location` section after `## Prerequisites` (no Agent Teams section in this command).
- In Input (line 10): change `docs/requirements/` → `{output-base}/requirements/`.
- In Prerequisites (line 16): change `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md`.
- In Output Format (line 76): change `docs/requirements/flow-catalog.md` → `{output-base}/requirements/flow-catalog.md`.
- In Next step (line 197): change `docs/requirements/` → `{output-base}/requirements/` in the example invocation.

**Verify**: Read both modified files from disk. Grep for remaining `docs/` references. Confirm source-dir references unchanged.

---

### 2.3. Checkpoint 3 — Stage 4-4c Commands

**Build**: Modify `commands/generalize-requirements.md`, `commands/generalize-ddd-analysis.md`, and `commands/generalize-flows.md`.

For `generalize-requirements.md`:
- Insert `## Output Location` after `## Prerequisites` (before `## Process`).
- Input (line 10): change `docs/requirements/` → `{output-base}/requirements/`.
- Prerequisites (lines 16-17): change `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md`.
- Output Format (lines 114, 117-118): change `docs/generalized-requirements/` → `{output-base}/generalized-requirements/` and both output filenames.
- Next step (line 250): change `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md`, `docs/requirements/flow-catalog.md` → `{output-base}/requirements/flow-catalog.md`.

For `generalize-ddd-analysis.md`:
- Insert `## Output Location` after `## Prerequisites` (before `## Process`).
- Input (line 10): change `docs/generalized-requirements/` → `{output-base}/generalized-requirements/`.
- Prerequisites (lines 16-20): change `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md`, `docs/generalized-requirements/business-requirements.md` → `{output-base}/generalized-requirements/business-requirements.md`, `docs/generalized-requirements/technical-requirements.md` → `{output-base}/generalized-requirements/technical-requirements.md`.
- Phase 3 (line 56): change `docs/generalized-requirements/service-decomposition.md` → `{output-base}/generalized-requirements/service-decomposition.md`.
- Output Format (line 73): change `docs/generalized-requirements/ddd-analysis.md` → `{output-base}/generalized-requirements/ddd-analysis.md`.
- Next step (line 103): change `docs/requirements/flow-catalog.md` → `{output-base}/requirements/flow-catalog.md`.

For `generalize-flows.md`:
- Insert `## Output Location` after `## Prerequisites` (before `## Process`).
- Input (line 10): change `docs/generalized-requirements/` → `{output-base}/generalized-requirements/`.
- Prerequisites (lines 16-22): change `docs/requirements/flow-catalog.md` → `{output-base}/requirements/flow-catalog.md`, both generalized requirements paths, and `docs/generalized-requirements/ddd-analysis.md` → `{output-base}/generalized-requirements/ddd-analysis.md`.
- Output Format (line 83): change `docs/generalized-requirements/flow-catalog.md` → `{output-base}/generalized-requirements/flow-catalog.md`.
- Next step (line 118): no path change needed (just mentions `/decompose-services`).

**Verify**: Read all three modified files. Grep for remaining `docs/` references. Confirm the relative markdown cross-references within generated document templates (e.g., `../ddd-analysis.md`, `./business-requirements.md`) are left unchanged — these are relative links within the vault structure and still work.

---

### 2.4. Checkpoint 4 — Stage 5-7 Commands

**Build**: Modify `commands/decompose-services.md`, `commands/generate-jira-tasks.md`, and `commands/review-requirements.md`.

For `decompose-services.md`:
- Insert `## Output Location` after `## Prerequisites` (before `## Process`).
- Input (line 10): change `docs/generalized-requirements/` → `{output-base}/generalized-requirements/`.
- Prerequisites (lines 16-18): change `docs/generalized-requirements/flow-catalog.md` → `{output-base}/generalized-requirements/flow-catalog.md`, `docs/generalized-requirements/ddd-analysis.md` → `{output-base}/generalized-requirements/ddd-analysis.md`, `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md`.
- Output Format (line 85): change `docs/generalized-requirements/service-decomposition.md` → `{output-base}/generalized-requirements/service-decomposition.md`.

For `generate-jira-tasks.md`:
- Insert `## Output Location` after `## Agent Teams Mode` (before `## Process`).
- Input (line 10): change `docs/generalized-requirements/` → `{output-base}/generalized-requirements/`.
- Prerequisites (lines 16-20): change all `docs/` references to `{output-base}/` equivalents: `service-decomposition.md`, `docs/generalized-requirements/ddd-analysis.md`, `docs/ddd-analysis.md`, `docs/generalized-requirements/flow-catalog.md`.
- Agent Teams section (lines 34-36): change `docs/generalized-requirements/jira-tasks.{service-N}.md` → `{output-base}/generalized-requirements/jira-tasks.{service-N}.md`.
- Agent Teams coordination (line 42): change `docs/generalized-requirements/technical-requirements.observability-and-testing.md` → `{output-base}/generalized-requirements/technical-requirements.observability-and-testing.md`.
- Output Format (line 208): change `docs/generalized-requirements/jira-tasks.{service-name}.md` → `{output-base}/generalized-requirements/jira-tasks.{service-name}.md`.
- Output Format observability doc (line 251): change `docs/generalized-requirements/technical-requirements.observability-and-testing.md` → `{output-base}/generalized-requirements/technical-requirements.observability-and-testing.md`.
- Output Format checklist (line 313): change `docs/generalized-requirements/jira-checklist.observability.md` → `{output-base}/generalized-requirements/jira-checklist.observability.md`.

For `review-requirements.md`:
- Insert `## Output Location` after `## Agent Teams Mode` (before `## Process`).
- Input (line 10): change `docs/generalized-requirements/` → `{output-base}/generalized-requirements/` and `docs/requirements/` → `{output-base}/requirements/`.
- Prerequisites (lines 17-19): change all `docs/` references: `docs/generalized-requirements/ddd-analysis.md`, `docs/ddd-analysis.md`, `docs/generalized-requirements/service-decomposition.md`, `docs/generalized-requirements/flow-catalog.md`, `docs/requirements/flow-catalog.md`.
- Check 1 ID table (lines 60-66): change all `docs/` paths to `{output-base}/` equivalents for every ID prefix row.
- Output Format (line 200): change `docs/generalized-requirements/review-findings.md` → `{output-base}/generalized-requirements/review-findings.md` and `docs/requirements/review-findings.md` → `{output-base}/requirements/review-findings.md`.

**Verify**: Read all three modified files. Grep for remaining `docs/` references. Pay special attention to the Check 1 table in `review-requirements.md` — every path must be updated.

---

### 2.5. Checkpoint 5 — Pipeline Table, Ingest Command, and Prompt Rules

**Build**:

**A. Update `commands/pipeline.md`**:
- Replace all `docs/...` paths in the Output column with `{output-base}/...` equivalents.
- Replace all `docs/...` paths in the Quick Start invocations with `{output-base}/...` equivalents. Since these are `$ARGUMENTS` passed to commands, they need the full vault path pattern. Change the Quick Start to show the vault-based paths:
  ```
  /extract-requirements {output-base}/codebase-analysis/reading-order.md
  /extract-flows {output-base}/requirements/
  /generalize-requirements {output-base}/requirements/
  /generalize-ddd-analysis {output-base}/generalized-requirements/
  /generalize-flows {output-base}/generalized-requirements/
  /decompose-services {output-base}/generalized-requirements/
  /generate-jira-tasks {output-base}/generalized-requirements/
  /review-requirements {output-base}/generalized-requirements/
  /ingest-second-brain
  ```
- Add a note at the top of Quick Start explaining how to resolve `{output-base}`: "Where `{output-base}` is `$OBSIDIAN_VAULT/Pipeline/{project-name}/`. Read `~/.claude/.env` for `$OBSIDIAN_VAULT`, derive project name from `basename $(git rev-parse --show-toplevel)`."
- Add Stage 8 row to the pipeline table:
  ```
  | 8 | `/ingest-second-brain` | Second brain database updated | All pipeline stages complete (documents exist in Obsidian vault) |
  ```
- Update Notes section: change `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md` and `docs/generalized-requirements/ddd-analysis.md` → `{output-base}/generalized-requirements/ddd-analysis.md`.

**B. Create `commands/ingest-second-brain.md`**:

New file with this content:

```markdown
---
description: "Ingest pipeline documents from the Obsidian vault into the second brain"
---

You are ingesting pipeline output documents into the second brain for semantic search and recall.

## Input

$ARGUMENTS is an optional project name override. If empty, derive the project name from `basename $(git rev-parse --show-toplevel)`.

## Prerequisites

Pipeline documents must exist in the Obsidian vault at `$OBSIDIAN_VAULT/Pipeline/{project-name}/`. If the directory does not exist or contains no `.md` files, stop and tell the user to run the pipeline stages first.

## Process

1. Read `~/.claude/.env` to get the `OBSIDIAN_VAULT` path.
2. Determine the project name (from `$ARGUMENTS` or `basename $(git rev-parse --show-toplevel)`).
3. Verify the vault directory exists: `$OBSIDIAN_VAULT/Pipeline/{project-name}/`
4. Run the ingest script in replace mode (default):
   ```bash
   python3 ~/.claude/scripts/second-brain/ingest.py "$OBSIDIAN_VAULT/Pipeline/{project-name}" "{project-name}"
   ```
5. Report the result: number of documents ingested and the project name used.

## Important

- Replace mode is the default — it deletes old chunks for this project before ingesting, ensuring the second brain reflects the latest pipeline output.
- This is the final pipeline stage. Run it after all other stages are complete.
- If the ingest script fails, report the error message to the user.
```

**C. Update `skills/prompt-rules/SKILL.md`**:
- Line 34: change `They have their own output conventions in \`docs/\`.` → `They write output to the Obsidian vault (see \`/pipeline\` for details).`

**Verify**: Read all three files from disk. For `pipeline.md`: confirm all `docs/` references are replaced, Stage 8 is present, and Quick Start shows vault paths. For `ingest-second-brain.md`: confirm it references `~/.claude/.env` and uses the correct ingest script path. For `prompt-rules/SKILL.md`: confirm the updated line.

---

## 3. Files to Create/Modify

| Action | File |
|--------|------|
| Modify | `commands/ddd-analysis.md` |
| Modify | `commands/analyze-codebase.md` |
| Modify | `commands/extract-requirements.md` |
| Modify | `commands/extract-flows.md` |
| Modify | `commands/generalize-requirements.md` |
| Modify | `commands/generalize-ddd-analysis.md` |
| Modify | `commands/generalize-flows.md` |
| Modify | `commands/decompose-services.md` |
| Modify | `commands/generate-jira-tasks.md` |
| Modify | `commands/review-requirements.md` |
| Modify | `commands/pipeline.md` |
| Create | `commands/ingest-second-brain.md` |
| Modify | `skills/prompt-rules/SKILL.md` |

---

## 4. Metadata

### Status
success

### Dependencies
- `~/.claude/.env` must contain `OBSIDIAN_VAULT` path
- `~/.claude/scripts/second-brain/ingest.py` must exist for Stage 8

### Open Questions
- None

### Assumptions
- Pipeline is always run from within a git repo (for `basename $(git rev-parse --show-toplevel)`)
- The `{output-base}` placeholder in command prompts is resolved at runtime by Claude reading `~/.claude/.env` — it is not a literal shell variable expansion
- Relative markdown cross-references within generated documents (e.g., `../ddd-analysis.md`) remain valid because the subdirectory structure is preserved

<!-- Self-review: converged after 1 pass -->
