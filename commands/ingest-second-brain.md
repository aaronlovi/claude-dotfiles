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
