---
name: run-prompt
description: Execute prompts from .prompts/
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, AskUserQuestion
argument-hint: [target]
user-invocable: true
---

# Run Prompt

Execute a prompt from `.prompts/`.

**Target**: $ARGUMENTS

## Steps

1. **Read project guidelines**
   - `CLAUDE.md` (required if exists)

2. **Resolve target**

   | Input | Resolves To |
   |-------|-------------|
   | (empty) | Ask user to choose from available prompts. If no `.prompts/` directory exists, say: "No prompts found. Create one with `/create-prompt` or `/create-meta-prompt`." |
   | `3`, `03`, or `003` (bare numbers — zero-padded to 3 digits) | `.prompts/003-*.md` |
   | `auth` (substring match) | `.prompts/*auth*.md` or `.prompts/auth-*/prompt.md` |
   | `auth-research` | `.prompts/auth-research/prompt.md` |
   | Full path (exists) | Use directly |
   | Full path (doesn't exist) | Report: "File not found at {path}. Check the path and try again." |

   If multiple matches (including numeric collisions like `003-foo.md` and `003-bar.md`), list and ask user to choose. When both file matches (`.prompts/*auth*.md`) and directory matches (`.prompts/auth-*/prompt.md`) exist, list all matches and ask the user to choose.

   When resolving targets, exclude `.progress.md` files from matches — these are progress tracking files, not prompts.

   If no prompts match the target, say: "No prompt matching `{target}` found in `.prompts/`. Available prompts: [list]. Or create one with `/create-prompt` or `/create-meta-prompt`."

3. **Read the prompt and execute**

## Execution by Prompt Type

### Task Prompts (`.prompts/NNN-name.md`)

Task prompts contain checkpoints as numbered subsections under `## Checkpoints` (see the template in `/create-prompt`). Execute each checkpoint using the checkpoint workflow:
1. Implement checkpoint (code + tests)
2. Stop, report what was done
3. Wait for user: review, compile, test
4. User confirms: clean compile, tests pass, committed
5. Proceed to next checkpoint

### Research Prompts (`.prompts/{slug}-research/prompt.md`)

Research prompts are single-pass (no checkpoint workflow, no progress tracking):
1. Read the prompt
2. Explore the codebase (read files, search for patterns)
3. Answer the research questions
4. Write findings to `.prompts/{slug}-research/research.md` with metadata block (Status, Dependencies, Open Questions, Assumptions)
5. Report: "Research complete. Written to `.prompts/{slug}-research/research.md`. Run `/create-meta-prompt [task]` (use the same task description) to generate the plan phase."

### Plan Prompts (`.prompts/{slug}-plan/prompt.md`)

**First run** (no plan.md exists):
1. Read research.md (always present for plans created via `/create-meta-prompt`; may be absent for manually created plan prompts). If the prompt references research.md but the file doesn't exist, inform the user: "This plan references research at `.prompts/{slug}-research/research.md` which doesn't exist. Run `/create-meta-prompt [task]` to create and execute the research phase first."
2. Design checkpoints per the prompt instructions
3. Write `.prompts/{slug}-plan/plan.md` with metadata block
4. Report: "Plan created. Run `/run-prompt {slug}-plan` again to implement."

**Second run** (plan.md exists):
1. Read plan.md. If plan.md exists but is empty or contains no checkpoints, treat it as a first run (regenerate the plan).
2. Check the metadata Status field — if `failed`, ask user whether to regenerate the plan. If `partial`, inform the user and ask whether to proceed or re-run the plan phase.
3. Execute checkpoints using the checkpoint workflow
4. After each checkpoint: stop, report, wait for user confirmation
5. After all checkpoints: "Implementation complete."

## Checkpoint Workflow (CRITICAL)

For implementation work, execute ONE CHECKPOINT AT A TIME:

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

**Never batch. Never skip review. Never proceed without confirmation. Never leave tests for a later checkpoint.**

Exception: a checkpoint that is purely non-code work (documentation, configuration) does not need unit tests.

## Progress Tracking

Track progress in:
- Task prompts: `.prompts/NNN-name.progress.md`
- Plan prompts: `.prompts/{slug}-plan/progress.md`

Before starting, check if progress.md exists:
- If yes, read it. If all checkpoints are already marked complete, report: "All checkpoints already complete. Nothing to do. Progress: .prompts/[path]/progress.md" and stop. Otherwise, resume from first incomplete checkpoint.
- If no, create it with all checkpoints marked pending

Also check the metadata Status field in plan.md or research.md (if applicable). If Status is `partial` or `failed`, inform the user and ask whether to proceed with the current plan or re-run the previous phase first. If research findings are insufficient to create a meaningful plan, recommend re-running research with refined questions rather than proceeding. If plan.md has Status `failed`, ask the user if they want to regenerate the plan (treat as a first run).

If progress.md is inconsistent with the plan (e.g., references checkpoints that don't exist, or shows out-of-order completion), report the inconsistency and ask the user how to proceed.

After user confirms each checkpoint, update progress.md:
```markdown
# Progress

- [x] Checkpoint 1: [description]
  - Files: [list of files modified]
  - Tests: [list of tests added]
  - Committed: [yes/hash]

- [ ] Checkpoint 2: [description]
  - (pending)
```

## Reporting

After checkpoint:
```
Checkpoint N of M complete:
- Implemented: [summary]
- Files: [list]
- Tests: [list]

Please review, compile, and run tests. Let me know the results.
```

After user confirms:
```
Checkpoint N confirmed. Progress saved.
Proceeding to checkpoint N+1.
```

When resuming:
```
Found existing progress: checkpoints 1-2 complete.
Resuming from checkpoint 3.
```

After all done:
```
All checkpoints complete. Implementation finished.
Progress: .prompts/[path]/progress.md
```
