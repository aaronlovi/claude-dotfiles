# Research Findings: Pipeline Output to Obsidian Vault with Second Brain Ingestion

## Table of Contents

- [1. Output Path Resolution per Command](#1-output-path-resolution-per-command)
- [2. Obsidian Vault Directory Structure](#2-obsidian-vault-directory-structure)
- [3. Reading $OBSIDIAN_VAULT from Commands](#3-reading-obsidian_vault-from-commands)
- [4. Cross-References Between Pipeline Stages](#4-cross-references-between-pipeline-stages)
- [5. Ingest Script Compatibility](#5-ingest-script-compatibility)
- [6. New Ingest Pipeline Stage](#6-new-ingest-pipeline-stage)
- [7. Recommended Approach](#7-recommended-approach)
- [8. Risks and Concerns](#8-risks-and-concerns)

---

## 1. Output Path Resolution per Command

Every pipeline command uses hardcoded relative paths under `docs/` in the current working directory. No command reads `$OBSIDIAN_VAULT` or any environment variable for output location.

| Command | Output Path(s) | Location in Prompt |
|---------|---------------|-------------------|
| `/ddd-analysis` | `docs/ddd-analysis.md` | `commands/ddd-analysis.md` line 191: "write the output to `docs/ddd-analysis.md`" |
| `/analyze-codebase` | `docs/codebase-analysis/reading-order.md` | `commands/analyze-codebase.md` line 98: "write to `docs/codebase-analysis/reading-order.md`" |
| `/extract-requirements` | `docs/requirements/business-requirements.md`, `docs/requirements/technical-requirements.md` | `commands/extract-requirements.md` lines 107-109 |
| `/extract-flows` | `docs/requirements/flow-catalog.md` | `commands/extract-flows.md` line 76 |
| `/generalize-requirements` | `docs/generalized-requirements/business-requirements.md`, `docs/generalized-requirements/technical-requirements.md` | `commands/generalize-requirements.md` lines 114-118 |
| `/generalize-ddd-analysis` | `docs/generalized-requirements/ddd-analysis.md` | `commands/generalize-ddd-analysis.md` line 73 |
| `/generalize-flows` | `docs/generalized-requirements/flow-catalog.md` | `commands/generalize-flows.md` line 83 |
| `/decompose-services` | `docs/generalized-requirements/service-decomposition.md` | `commands/decompose-services.md` line 85 |
| `/generate-jira-tasks` | `docs/generalized-requirements/jira-tasks.{service-name}.md`, `docs/generalized-requirements/technical-requirements.observability-and-testing.md`, `docs/generalized-requirements/jira-checklist.observability.md` | `commands/generate-jira-tasks.md` lines 208, 251, 313 |
| `/review-requirements` | `docs/generalized-requirements/review-findings.md` (or `docs/requirements/review-findings.md`) | `commands/review-requirements.md` line 200 |

All paths are relative to the CWD where the command runs. The `docs/` prefix is hardcoded in every prompt's "Output Format" section and also appears throughout "Prerequisites" sections where commands reference upstream artifacts.

## 2. Obsidian Vault Directory Structure

The vault is at `$OBSIDIAN_VAULT` (currently `/mnt/c/Users/aaron/ObsidianVaults/DevNotes`).

### Recommended structure

```
$OBSIDIAN_VAULT/
└── Pipeline/
    └── {project-name}/
        ├── ddd-analysis.md
        ├── codebase-analysis/
        │   └── reading-order.md
        ├── requirements/
        │   ├── business-requirements.md
        │   ├── technical-requirements.md
        │   └── flow-catalog.md
        └── generalized-requirements/
            ├── business-requirements.md
            ├── technical-requirements.md
            ├── ddd-analysis.md
            ├── flow-catalog.md
            ├── service-decomposition.md
            ├── jira-tasks.{service-name}.md
            ├── technical-requirements.observability-and-testing.md
            ├── jira-checklist.observability.md
            └── review-findings.md
```

### Rationale

- **`Pipeline/` top-level folder**: Groups all pipeline outputs separate from other vault content. Easily findable in Obsidian's file explorer.
- **`{project-name}/` subfolder**: Isolates per-project outputs. No collisions between projects.
- **Preserves `requirements/` and `generalized-requirements/` subdirectory structure**: Critical for the ingest script's specificity detection (see Q5). Files under `generalized-requirements/` are tagged `generalized`; everything else is `project_specific`.
- **Flat `ddd-analysis.md` at project root**: Matches the current structure where `docs/ddd-analysis.md` sits at the top level of `docs/`.

### Alternative considered: `docs/` subfolder inside project

Wrapping everything in `Pipeline/{project-name}/docs/` would minimize changes to prompts (just prefix with the vault path), but the extra `docs/` level adds no value in the Obsidian context and makes navigation slightly worse.

## 3. Reading $OBSIDIAN_VAULT from Commands

### How env vars work in this system

Slash command prompts are plain markdown processed by Claude. They cannot directly expand shell environment variables. The `$ARGUMENTS` placeholder is substituted by Claude Code's command system, but `$OBSIDIAN_VAULT` is not — it's defined in `~/.claude/.env` and must be read at runtime.

### Recommended approach

Each command prompt should include an **Output Location** section near the top that instructs Claude to:

1. Read `~/.claude/.env` to get `$OBSIDIAN_VAULT`
2. Derive the project name from the current git repo's directory name (using `basename $(git rev-parse --show-toplevel)`) or accept it as part of `$ARGUMENTS`
3. Construct the output base path: `$OBSIDIAN_VAULT/Pipeline/{project-name}/`
4. Create the directory structure with `mkdir -p` before writing

### Project name derivation

The pipeline is always run from within a project repo. Using `basename $(git rev-parse --show-toplevel)` is reliable and automatic. However, `$ARGUMENTS` is already used for the source directory. Options:

- **Option A**: Derive project name automatically from git repo name. Simplest; requires no user input change.
- **Option B**: Add an optional `--project` flag parsed from `$ARGUMENTS`. More flexible but changes the invocation for all commands.

**Recommendation**: Option A — derive automatically. The user can override by setting a project-specific env var in `.env` if needed.

## 4. Cross-References Between Pipeline Stages

Commands reference upstream outputs using hardcoded `docs/` paths in two locations:

### A. Prerequisites sections (input paths)

| Command | Reads From |
|---------|-----------|
| `/analyze-codebase` | `docs/ddd-analysis.md` (optional) |
| `/extract-requirements` | `docs/codebase-analysis/reading-order.md` (optional), `docs/ddd-analysis.md` (optional) |
| `/extract-flows` | `docs/requirements/` directory (required) |
| `/generalize-requirements` | `docs/requirements/` directory (required), `docs/ddd-analysis.md` (optional) |
| `/generalize-ddd-analysis` | `docs/ddd-analysis.md` (required), `docs/generalized-requirements/` (required) |
| `/generalize-flows` | `docs/requirements/flow-catalog.md` (required), `docs/generalized-requirements/` (required) |
| `/decompose-services` | `docs/generalized-requirements/` (required), `docs/generalized-requirements/ddd-analysis.md` or `docs/ddd-analysis.md` (optional) |
| `/generate-jira-tasks` | `docs/generalized-requirements/` (required), `docs/generalized-requirements/ddd-analysis.md` or `docs/ddd-analysis.md` (optional) |
| `/review-requirements` | `docs/generalized-requirements/` or `docs/requirements/` (required), `docs/ddd-analysis.md` (optional) |

### B. Markdown cross-references within generated documents

Several output documents contain relative markdown links to sibling documents:
- `generalize-ddd-analysis` output includes: `"Generalized from [original DDD analysis](../ddd-analysis.md)"` and `[business requirements](./business-requirements.md)`
- `generalize-flows` output includes similar cross-references

These relative links will still work correctly in the new vault structure because the relative relationships between files are preserved (e.g., `generalized-requirements/ddd-analysis.md` links to `../ddd-analysis.md` which resolves to the project root's `ddd-analysis.md`).

### C. Quick Start invocations in `pipeline.md`

The pipeline table shows example invocations like:
```
/extract-requirements docs/codebase-analysis/reading-order.md
/extract-flows docs/requirements/
/generalize-requirements docs/requirements/
```

These pass `docs/` paths as `$ARGUMENTS`. Once outputs live in the Obsidian vault, these arguments must point to the vault path instead.

### Impact

All `docs/` references in both:
1. **Prerequisites sections** (where commands look for upstream artifacts)
2. **Pipeline quick-start invocations** (the `$ARGUMENTS` examples)

...must be updated to use the vault-based path. The relative markdown links within generated documents do NOT need changes because the directory structure is preserved.

## 5. Ingest Script Compatibility

The ingest script (`~/.claude/scripts/second-brain/ingest.py`) will work with the new vault paths **without modification**.

### Specificity detection

`detect_specificity()` (line 47-51) checks if `"generalized-requirements"` is in the relative path parts. The relative path is computed from the `docs_path` argument:

```python
rel_path = md_file.relative_to(docs_path)
```

If invoked as:
```bash
python ingest.py "$OBSIDIAN_VAULT/Pipeline/identity-server" identity-server
```

Then for `$OBSIDIAN_VAULT/Pipeline/identity-server/generalized-requirements/business-requirements.md`, the relative path is `generalized-requirements/business-requirements.md`, and `"generalized-requirements"` will be in `rel_path.parts`. Detection works correctly.

### Doc type detection

`detect_doc_type()` (line 38-43) uses filename patterns only (`md_file.name`). Filenames don't change. Works correctly.

### No changes needed to the ingest script.

## 6. New Ingest Pipeline Stage

### Recommended: New slash command `/ingest-second-brain`

A new command at `commands/ingest-second-brain.md` is the cleanest approach:

- **Arguments**: `$ARGUMENTS` = project name (optional; defaults to `basename $(git rev-parse --show-toplevel)`)
- **Behavior**: Read `~/.claude/.env` to get `$OBSIDIAN_VAULT`, construct the vault path, run the ingest script
- **Replace mode** (default, no `--append`): Since pipeline stages overwrite their outputs, the second brain should reflect the latest state. Replace mode deletes old chunks before ingesting, preventing stale data.

### Invocation

```bash
python3 ~/.claude/scripts/second-brain/ingest.py "$OBSIDIAN_VAULT/Pipeline/{project-name}" "{project-name}"
```

### Pipeline table addition

Add as Stage 8:

| Stage | Command | Output | Prerequisites |
|-------|---------|--------|---------------|
| 8 | `/ingest-second-brain` | Second brain database updated | All pipeline documents generated in the Obsidian vault |

## 7. Recommended Approach

### Changes needed

1. **All 10 pipeline commands**: Replace hardcoded `docs/` output paths with vault-based paths. Add an "Output Location" section that reads `~/.claude/.env` and derives the project name.

2. **All 10 pipeline commands**: Replace hardcoded `docs/` input paths in Prerequisites sections with vault-based paths.

3. **`pipeline.md`**: Update the quick-start invocations, the output column, and add Stage 8 (`/ingest-second-brain`).

4. **New command**: Create `commands/ingest-second-brain.md`.

5. **No changes to ingest.py**.

### Pattern for the "Output Location" section

Each command should have a new section after "Input" (or "Prerequisites"):

```markdown
## Output Location

Before writing any output, determine the output base directory:

1. Read `~/.claude/.env` to get the `OBSIDIAN_VAULT` path.
2. Derive the project name: `basename $(git rev-parse --show-toplevel)`
3. Set output base: `$OBSIDIAN_VAULT/Pipeline/{project-name}/`
4. Create the output directory with `mkdir -p` if it doesn't exist.

All output paths in this command are relative to this base directory (not the current working directory).
```

Then replace all `docs/...` output references with paths relative to the base directory (e.g., `docs/ddd-analysis.md` → `{output-base}/ddd-analysis.md`).

For input paths in Prerequisites, use the same vault resolution logic to locate upstream artifacts.

## 8. Risks and Concerns

1. **WSL path performance**: The vault is at `/mnt/c/...` (Windows filesystem via WSL). File I/O on `/mnt/c/` is significantly slower than native Linux paths. Writing many files during pipeline execution may be noticeably slower. Mitigations: the pipeline writes ~10-15 files total, each relatively small, so this should be tolerable.

2. **Pipeline commands run in the app repo's CWD**: Commands use `$ARGUMENTS` to locate source code (e.g., `/ddd-analysis src/`). Source code stays in the repo; only outputs move to the vault. The commands must clearly separate "read from CWD/source" and "write to vault path."

3. **Obsidian indexing**: Obsidian watches the vault directory for changes. Writing files while Obsidian is running is fine — Obsidian handles live updates. No conflicts expected.

4. **Git tracking**: Pipeline outputs will no longer be in the project repo's git tree. This is intentional (the user explicitly wants this), but it means outputs won't be version-controlled via the project's git. If version control is desired, the Obsidian vault itself could be a git repo (common Obsidian pattern).

5. **Existing `docs/` directories in project repos**: Projects that already have `docs/` directories with pipeline output will need manual cleanup. The commands should not delete existing `docs/` directories — that's a user decision.

6. **Multiple pipeline runs on the same project**: Using replace mode for ingest is correct — each full pipeline run produces the complete, latest set of documents. Partial re-runs (e.g., re-running only Stage 7) will overwrite only that stage's output file; the ingest at Stage 8 will re-ingest all files.

---

## Metadata
### Status
success
### Dependencies
- `~/.claude/.env` must contain `OBSIDIAN_VAULT` path
- Obsidian vault directory must exist and be writable
### Open Questions
- None
### Assumptions
- Project name will be derived from `basename $(git rev-parse --show-toplevel)` — assumes pipeline is always run from within a git repo
- The Obsidian vault directory structure does not need a `docs/` wrapper — the `Pipeline/{project}/` prefix is sufficient organization

<!-- Self-review: converged after 1 pass -->
