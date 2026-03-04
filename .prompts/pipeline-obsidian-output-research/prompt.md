# Research: Pipeline Output to Obsidian Vault with Second Brain Ingestion

## Objective
Understand what changes are needed to redirect all pipeline stage outputs from the project repo's `docs/` directory to the Obsidian vault, and how to add a final pipeline stage that ingests the generated documents into the second brain.

## Context
- Guidelines: `CLAUDE.md`, `~/.claude/CLAUDE.md`
- Machine-specific config: `~/.claude/.env` (contains `OBSIDIAN_VAULT` path)
- Pipeline definition: `commands/pipeline.md`
- Pipeline stage commands: `commands/ddd-analysis.md`, `commands/analyze-codebase.md`, `commands/extract-requirements.md`, `commands/extract-flows.md`, `commands/generalize-requirements.md`, `commands/generalize-ddd-analysis.md`, `commands/generalize-flows.md`, `commands/decompose-services.md`, `commands/generate-jira-tasks.md`, `commands/review-requirements.md`
- Second brain ingest script: `~/.claude/scripts/second-brain/ingest.py`
- Second brain recall script: `~/.claude/scripts/second-brain/recall.py`
- Obsidian vault: path from `$OBSIDIAN_VAULT` env var (currently `/mnt/c/Users/aaron/ObsidianVaults/DevNotes`)

## Prior Knowledge
- The second brain ingest script accepts `<project_docs_path> <project_name> [--append]`, scans recursively for `.md` files, splits by heading, embeds with `all-MiniLM-L6-v2`, and stores in PostgreSQL with pgvector.
- Doc type detection is filename-based (`ddd-analysis*` → `ddd`, `business-requirements*` → `brd`, etc.).
- Specificity detection uses the relative path — files under `generalized-requirements/` are tagged `generalized`.

## Questions to Answer

1. **How does each pipeline command currently resolve its output path?** For each of the 10 commands, identify the exact lines where output paths are defined (hardcoded `docs/...` strings vs. derived from arguments). Determine whether paths are absolute or relative to CWD.

2. **How should the Obsidian vault directory structure be organized?** The vault is at `$OBSIDIAN_VAULT`. What subdirectory structure will:
   - Keep pipeline outputs organized per-project (since the pipeline runs against different repos)
   - Preserve the `docs/requirements/` and `docs/generalized-requirements/` subdirectory structure (needed for ingest specificity detection)
   - Be easy to browse in Obsidian's file explorer
   - Avoid collisions between projects

3. **How should commands read `$OBSIDIAN_VAULT`?** The env var is set in `~/.claude/.env`. Determine:
   - Whether slash command prompts can reference env vars directly or need explicit instructions to read `~/.claude/.env`
   - Whether the pipeline prompt should instruct the user to pass a project name, or derive it from the current repo/directory

4. **What cross-references exist between pipeline stages?** Several commands reference outputs from earlier stages (e.g., `extract-requirements` reads `reading-order.md`, `generalize-*` reads `docs/requirements/`). Catalog all inter-stage path references to ensure they still resolve correctly when outputs move to the vault.

5. **What changes does the ingest script need (if any) to work with the new vault paths?** The ingest script's specificity detection relies on `generalized-requirements/` appearing in the relative path. Verify this still works when the base path is inside the Obsidian vault instead of the project repo.

6. **How should the new "ingest" pipeline stage be defined?** Determine:
   - Should it be a new slash command (`/ingest-second-brain`) or just a step documented in `pipeline.md`?
   - What arguments does it need (project name, vault path)?
   - Should it use replace mode (default) or `--append`?

## Explore
- `commands/pipeline.md` — full pipeline definition and stage table
- `commands/ddd-analysis.md` — output path pattern
- `commands/analyze-codebase.md` — output path pattern
- `commands/extract-requirements.md` — output path pattern and cross-references to earlier stages
- `commands/extract-flows.md` — output path pattern
- `commands/generalize-requirements.md` — output path pattern and input references
- `commands/generalize-ddd-analysis.md` — output path pattern and input references
- `commands/generalize-flows.md` — output path pattern and input references
- `commands/decompose-services.md` — output path pattern and input references
- `commands/generate-jira-tasks.md` — output path pattern and input references
- `commands/review-requirements.md` — output path pattern and input references
- `~/.claude/scripts/second-brain/ingest.py` — ingestion logic, path handling, specificity detection
- `~/.claude/.env` — env var definitions
- `.env.example` — documentation of machine-specific settings

## Output
Write findings to `.prompts/pipeline-obsidian-output-research/research.md`:
- Answers to the questions above
- Existing patterns to follow
- Risks or concerns
- Recommended approach
- Metadata block (append at end):
  ## Metadata
  ### Status
  [success | partial | failed]
  ### Dependencies
  - [files or decisions this relies on, or "None"]
  ### Open Questions
  - [unresolved issues, or "None"]
  ### Assumptions
  - [what was assumed, or "None"]

<!-- Self-review: converged after 1 pass -->
