---
name: prompt-rules
description: Shared conventions for the prompt system
allowed-tools: []
user-invocable: false
---

# Prompt System Conventions

Reference for `/create-prompt`, `/create-meta-prompt`, and `/run-prompt`.

## Project Guidelines First

Always read `CLAUDE.md` before doing anything. Project rules override these conventions.

## When to Use Which Command

| Command | Use When |
|---------|----------|
| Dedicated pipeline command (e.g., `/ddd-analysis`) | A specific slash command exists for the task type |
| `/pipeline` | Need to see the available pipeline stages and their order |
| `/create-prompt` | Task is clear and can be implemented directly with checkpoints |
| `/create-meta-prompt` | Task needs exploration first, or is complex enough to benefit from explicit research/plan phases |
| `/run-prompt` | Execute an existing prompt from `.prompts/` |

Decision tree:
1. Is there a dedicated pipeline command for this task type? → Use it
2. Is the task well-defined and ready to implement? → `/create-prompt`
3. Does the task need exploration or research first? → `/create-meta-prompt`
4. Want to execute an existing prompt? → `/run-prompt`

If unsure, start with `/create-meta-prompt` — the research phase will clarify scope. If you need to read more than 5 files to understand the scope, or if there are multiple viable approaches, prefer `/create-meta-prompt` over `/create-prompt`.

**Note:** Pipeline commands like `/ddd-analysis`, `/extract-requirements`, `/generate-jira-tasks`, etc. are standalone workflow commands that do not use the `.prompts/` directory or checkpoint system. They have their own output conventions in `docs/`. See `/pipeline` for the full list.

## File Locations

```
.prompts/
  NNN-name.md                    # Task prompts (from /create-prompt)
  NNN-name.progress.md           # Progress tracking (from /run-prompt)
  {slug}-research/
    prompt.md                    # Research prompt
    research.md                  # Research output
  {slug}-plan/
    prompt.md                    # Plan prompt
    plan.md                      # Plan output
    progress.md                  # Progress tracking (from /run-prompt)
```

## Slug Rules

Derive from task: lowercase, hyphenate, drop stopwords (a, an, the, of, for, to).
Example: "Refactor the payment system" → `refactor-payment-system`

## Checkpoint Workflows

During implementation, execute ONE CHECKPOINT AT A TIME. Never batch. Never leave tests for a later checkpoint.

Exception: a checkpoint that is purely non-code work (documentation, configuration) does not need unit tests.

### Manual Checkpoint Workflow

Used by **task prompts**. Requires user confirmation at each checkpoint:

```
1. Check for existing progress.md - skip completed checkpoints
2. Implement checkpoint (code + unit tests for this checkpoint's code)
   - Unit tests are written IN the same checkpoint as the code they test
   - Never defer tests to a later checkpoint
3. Stop and report:
   - What was implemented
   - Files created/modified
   - Tests added
4. Ask user to review, compile, run tests
   - ALL tests (existing + new) must pass before proceeding
5. Wait for user to report results
6. Address any feedback
7. User confirms: compiles, ALL tests pass, committed
8. Update progress.md with completed checkpoint
9. Only then proceed to next checkpoint
```

**Never skip review. Never proceed without user confirmation.**

### Automated Checkpoint Workflow

Used by **plan prompts**. Claude performs review, compilation, testing, and commit autonomously:

```
1. Check for existing progress.md - skip completed checkpoints
2. Implement checkpoint (code + unit tests for this checkpoint's code)
   - Unit tests are written IN the same checkpoint as the code they test
   - Never defer tests to a later checkpoint
3. Self-verify loop (max 5 iterations):
   a. Re-read all files modified/created in this checkpoint from disk
   b. Review for: missing imports, type errors, obvious bugs, style violations,
      incomplete implementations, tests that don't match the code
   c. Compile the project
   d. Run ALL tests (existing + new)
   e. If ANY issues (review findings, compile errors, test failures):
      fix them all, then go back to step (a)
   f. If CLEAN (no review issues, compiles, all tests pass):
      exit the loop
4. Commit: git add the modified/created files and commit with message
   "Checkpoint {id}" (matching the checkpoint number from the plan,
   e.g., "Checkpoint 1", "Checkpoint 2.1")
5. Update progress.md with completed checkpoint and commit hash
6. Report what was done, then proceed to next checkpoint
```

If the self-verify loop does not converge after 5 iterations, stop and report
the remaining issues to the user. Do NOT proceed to the next checkpoint.

After all checkpoints complete, `/run-prompt` executes a **Finalization Phase**
that squashes checkpoint commits, reviews the full changeset, and performs a
wrap-up sweep. See `/run-prompt` for details.

## Metadata Block

Append to research.md, plan.md:

```markdown
## Metadata

### Status
[success | partial | failed]

### Dependencies
- [files or decisions this relies on, or "None"]

### Open Questions
- [unresolved issues, or "None"]

### Assumptions
- [what was assumed, or "None"]
```

## Progress Tracking

Track progress in:
- Task prompts: `.prompts/NNN-name.progress.md`
- Plan prompts: `.prompts/{slug}-plan/progress.md`

Format:
```markdown
# Progress

- [x] Checkpoint 1: [description]
  - Files: [list of files modified]
  - Tests: [list of tests added]
  - Committed: [yes/hash]

- [x] Checkpoint 2: [description]
  - Files: [list of files modified]
  - Tests: [list of tests added]
  - Committed: [yes/hash]

- [ ] Checkpoint 3: [description]
  - (pending)
```

For plan prompts, progress.md also includes a pre-implementation base ref and a finalization checklist. See `/run-prompt` for the extended format.

Before starting, check if progress.md exists:
- If yes, read it and resume from first incomplete checkpoint
- If no, create it with all checkpoints marked pending

Update after each checkpoint completes (user confirms for manual workflow; self-verify converges for automated workflow).

## Naming Conventions

Avoid naming task prompts with slugs that end in `-research` or `-plan` to prevent ambiguity with meta-prompt directories.

## Cleanup

A prompt is considered complete when all its checkpoints are marked `[x]` in progress.md. For plan prompts, the finalization checklist must also be fully marked `[x]` (see `/run-prompt`). Completed prompts can be deleted or moved to `.prompts/archive/` at the user's discretion. The prompt system does not automatically clean up old workflows.

## Resuming Incomplete Work

If a workflow was interrupted:
1. Check for `progress.md` to see completed checkpoints
2. Read metadata in research.md/plan.md to see status
3. If progress.md is inconsistent with the plan (e.g., references checkpoints that don't exist, or shows out-of-order completion), report the inconsistency and ask the user how to proceed
4. If Status is `partial` or `failed`, inform the user and ask whether to proceed or re-run the previous phase
5. Continue from the first incomplete checkpoint
6. For plan prompts: if all checkpoints are complete but the finalization checklist has incomplete items, resume the finalization phase from the first incomplete sub-step (see `/run-prompt`)
