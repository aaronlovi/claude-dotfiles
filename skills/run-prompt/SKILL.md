---
name: run-prompt
description: Execute prompts from .prompts/
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, AskUserQuestion, Task
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
   | (empty) | List all available prompts showing their number/slug, type (task/research/plan), and first line of the Objective section, then ask the user to choose. If no `.prompts/` directory exists, say: "No prompts found. Create one with `/create-prompt` or `/create-meta-prompt`." |
   | `3`, `03`, or `003` (bare numbers — zero-padded to 3 digits) | `.prompts/003-*.md` |
   | `auth` (substring match) | `.prompts/*auth*.md` or `.prompts/auth-*/prompt.md` |
   | `auth-research` | `.prompts/auth-research/prompt.md` |
   | Full path (exists) | Use directly |
   | Full path (doesn't exist) | Report: "File not found at {path}. Check the path and try again." |

   If resolution produces more than one match (regardless of match type — numeric, substring, or mixed file/directory), list all matches with their type and ask the user to choose.

   When resolving targets, exclude `.progress.md` files from matches — these are progress tracking files, not prompts.

   If no prompts match the target, say: "No prompt matching `{target}` found in `.prompts/`. Available prompts: [list]. Or create one with `/create-prompt` or `/create-meta-prompt`."

3. **Read the prompt and execute**

## Execution by Prompt Type

### Task Prompts (`.prompts/NNN-name.md`)

Task prompts contain checkpoints as numbered subsections under `## Checkpoints` (see the template in `/create-prompt`). Execute each checkpoint using the **manual** checkpoint workflow:
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
5. **Self-review the research output (mandatory convergence loop)** — do NOT skip this or do a single mental check. Execute this iterative loop:
   **For each pass (max 5):**
   a. **Re-read research.md from disk** using the Read tool. Do NOT rely on what you remember writing.
   b. **Evaluate against every criterion below.** Note all issues found.
   c. **If ANY issues found:** fix them all, then go back to step (a).
   d. **If NO issues found:** append `<!-- Self-review: converged after N passes -->` and stop.
   Batch all fixes from one pass before re-reading.
   **Criteria:**
   - **Consistency**: Findings don't contradict each other; file paths referenced actually exist; metadata Status accurately reflects completeness
   - **Correctness**: Questions from the prompt are all addressed (or explicitly marked unanswered in Open Questions); for each file path or code pattern cited in the findings, re-read the file to verify it exists and matches what was described — remove or correct any references to files or symbols that don't exist
   - **Information density**: Enough detail to write a plan from, but no padding. If an answer is "there is no existing pattern for X," say that directly — don't speculate. If findings are thin, set Status to `partial` and list gaps in Open Questions.
6. Report: "Research complete. Written to `.prompts/{slug}-research/research.md`. Run `/create-meta-prompt [task]` (use the same task description) to generate the plan phase."

### Plan Prompts (`.prompts/{slug}-plan/prompt.md`)

**First run** (no plan.md exists):
1. Read research.md (always present for plans created via `/create-meta-prompt`; may be absent for manually created plan prompts). If the prompt references research.md but the file doesn't exist, inform the user: "This plan references research at `.prompts/{slug}-research/research.md` which doesn't exist. Run `/create-meta-prompt [task]` to create and execute the research phase first."
2. Design checkpoints per the prompt instructions
3. Write `.prompts/{slug}-plan/plan.md` with metadata block
4. **Self-review the plan (mandatory convergence loop)** — do NOT skip this or do a single mental check. Execute this iterative loop:
   **For each pass (max 5):**
   a. **Re-read plan.md from disk** using the Read tool. Do NOT rely on what you remember writing.
   b. **Evaluate against every criterion below.** Note all issues found.
   c. **If ANY issues found:** fix them all, then go back to step (a).
   d. **If NO issues found:** append `<!-- Self-review: converged after N passes -->` and stop.
   Batch all fixes from one pass before re-reading.
   **Criteria:**
   - **Consistency**: Checkpoints use parallel structure; file paths match what research.md identified; no checkpoint references files or APIs that haven't been introduced in an earlier checkpoint
   - **Correctness**: Checkpoints are in buildable order (no forward dependencies); each checkpoint includes tests for its own code; research findings are accurately reflected (not contradicted or ignored)
   - **Information density**: Each checkpoint has enough specifics (which files, which functions, what behavior) for an LLM to implement without re-reading research. No redundant restatements across checkpoints. If research identified risks or constraints, they're addressed in the relevant checkpoint — not in a generic preamble.
5. Report: "Plan created. Run `/run-prompt {slug}-plan` again to implement."

**Second run** (plan.md exists):
1. Read plan.md. If plan.md exists but is empty or contains no checkpoints, treat it as a first run (regenerate the plan).
2. Check the metadata Status field — if `failed`, ask user whether to regenerate the plan. If `partial`, inform the user and ask whether to proceed or re-run the plan phase.
3. **Resolve the pre-implementation base**: if progress.md already contains a `Pre-implementation base: <hash>` line, read the `<base-ref>` from it. Otherwise (first run), run `git rev-parse HEAD`, store the result as `<base-ref>`, and write it to progress.md as `Pre-implementation base: <hash>` along with the `## Finalization` checklist (see Progress Tracking). If progress.md exists but has no base-ref (legacy format), fall back to `origin/main`.
4. Execute checkpoints using the **automated** checkpoint workflow (see `/prompt-rules`):
   - Implement each checkpoint, then self-verify (review, compile, test) in a loop (max 5 iterations)
   - On convergence: commit with "Checkpoint {id}" and update progress.md
   - On failure to converge: stop and report remaining issues to the user
5. After all checkpoints complete: proceed to the **Finalization Phase**.

## Checkpoint Workflows

Follow the checkpoint workflows defined in `/prompt-rules`:
- **Task prompts** use the **manual** checkpoint workflow: implement, stop, wait for user review/compile/test confirmation.
- **Plan prompts** use the **automated** checkpoint workflow: implement, self-verify (review + compile + test loop, max 5 iterations), commit, proceed.
- In both workflows: execute ONE CHECKPOINT AT A TIME. Never batch. Never leave tests for a later checkpoint.
- Exception: a checkpoint that is purely non-code work (documentation, configuration) does not need unit tests.

## Progress Tracking

Track progress in:
- Task prompts: `.prompts/NNN-name.progress.md`
- Plan prompts: `.prompts/{slug}-plan/progress.md`

Before starting, check if progress.md exists:
- If yes, read it. If all checkpoints are marked complete AND finalization is marked complete (plan prompts only), report: "All checkpoints and finalization already complete. Nothing to do. Progress: .prompts/[path]/progress.md" and stop. If all checkpoints are complete but finalization is pending (or not tracked), resume at the finalization phase. Otherwise, resume from first incomplete checkpoint.
- If no, create it with all checkpoints marked pending. For plan prompts, also include the `Pre-implementation base` and `## Finalization` checklist (see format below).

Also check the metadata Status field in plan.md or research.md (if applicable). If Status is `partial` or `failed`, inform the user and ask whether to proceed with the current plan or re-run the previous phase first. If research findings are insufficient to create a meaningful plan, recommend re-running research with refined questions rather than proceeding. If plan.md has Status `failed`, ask the user if they want to regenerate the plan (treat as a first run).

If progress.md is inconsistent with the plan (e.g., references checkpoints that don't exist, or shows out-of-order completion), report the inconsistency and ask the user how to proceed.

After each checkpoint completes (user confirms for task prompts; self-verify converges for plan prompts), update progress.md:
```markdown
# Progress

- [x] Checkpoint 1: [description]
  - Files: [list of files modified]
  - Tests: [list of tests added]
  - Committed: [yes/hash]

- [ ] Checkpoint 2: [description]
  - (pending)
```

For plan prompts, progress.md also tracks the pre-implementation base and finalization status:
```markdown
# Progress

Pre-implementation base: <hash>

- [x] Checkpoint 1: [description]
  - Files: [list]
  - Tests: [list]
  - Committed: [hash]

## Finalization
- [ ] Squash
- [ ] Review-and-fix
- [ ] Wrap-up
```
Update each finalization sub-step as it completes during the finalization phase.

## Reporting

### Task Prompts (Manual Workflow)

After checkpoint:
```
Checkpoint N of M complete:
- Implemented: [summary]
- Files: [list]
- Tests added: [list]

Please review, compile, and run tests. Let me know the results.
```

After user confirms:
```
Checkpoint N confirmed. Progress saved.
Proceeding to checkpoint N+1.
```

### Plan Prompts (Automated Workflow)

After each checkpoint converges:
```
Checkpoint N of M complete:
- Implemented: [summary]
- Files: [list]
- Tests added: [list]
- Compiled: clean
- Test run: all passing
- Self-verify: converged after N iterations
- Committed: [hash]
Proceeding to checkpoint N+1.
```

If self-verify does not converge:
```
Checkpoint N of M — did not converge after 5 iterations.
Remaining issues:
- [list of unresolved compile errors, test failures, or review findings]

Please review and advise how to proceed.
```

### Common

When resuming:
```
Found existing progress: checkpoints 1-2 complete.
Resuming from checkpoint 3.
```

After all done (task prompts):
```
All checkpoints complete. Implementation finished.
Progress: .prompts/[path]/progress.md
```

After all done (plan prompts): proceed to the Finalization Phase — do not report "Implementation finished" until finalization completes.

## Finalization Phase (Plan Prompts Only)

After all checkpoints complete in a plan prompt execution, execute this finalization phase before reporting completion. This phase squashes checkpoint commits, reviews the full changeset, and performs a final quality sweep.

**Resuming**: if resuming an interrupted finalization, read progress.md in full — extract the `Pre-implementation base: <hash>` line (needed for `git reset --soft <base-ref>` in Step 1) and read the `## Finalization` checklist to identify which sub-steps are already marked `[x]`. Start from the first incomplete sub-step.

### Step 1: Squash Checkpoint Commits

Squash all checkpoint commits into a single descriptive commit:

```bash
git reset --soft <base-ref>
git commit -m "<descriptive message>"
```

The commit message should:
- Summarize the feature or changes implemented (not just "Checkpoint 1, 2, 3")
- Be derived from the plan's objective and the checkpoints completed
- Follow the project's commit message conventions (from CLAUDE.md if specified)
- Use conventional format: a short subject line (under 72 chars), blank line, then bullet points summarizing key changes

Update progress.md: mark `Squash` complete.

### Step 2: Review-and-Fix Loop (max 5 iterations)

Apply the same review criteria as `/review-squashed-changes`, but fix findings instead of just reporting them.

**For each pass (max 5):**

a. **Re-read all changed files from disk** and review the changeset using `git diff <base-ref>...HEAD`. Do NOT rely on what you remember from previous passes.
   - **Production code** (diff hunks): Correctness, security, API contract, edge cases, resource management, naming/clarity
   - **Test files** (full-file via `git show HEAD:<file>`): Correctness of assertions, DRY, data-driven test opportunities, refactoring opportunities
   - **Non-code files** (light pass): Hardcoded secrets, wrong values, contradictions
   - **Cross-cutting**: Consistency between code and tests, completeness, architectural fit

   If there are more than 5 changed files, use Task tool subagents to parallelize the review (group into batches of 3-5 related files per `general-purpose` subagent, then merge findings).

   Do NOT flag: style preferences (formatting, whitespace, import order) — assume a formatter handles this. Do NOT flag pre-existing issues in unchanged code.

b. **Note all findings.**

c. **If ANY findings:** fix all issues in the source files, then compile and run all tests. If compile errors or test failures result from fixes, fix those too. Then go back to step (a).

d. **If NO findings:** converged — stop.

Batch all fixes from one pass before re-reading.

After convergence (or max 5 passes), if any fixes were made, amend the squashed commit to include them:

```bash
git add -A
git commit --amend --no-edit
```

Update progress.md: mark `Review-and-fix` complete.

If not converged after 5 passes, report remaining issues to the user before proceeding to Step 3: Wrap-Up-and-Fix Loop.

### Step 3: Wrap-Up-and-Fix Loop (max 5 iterations)

Apply the same checks as `/wrap-up`, fixing issues directly.

**For each pass (max 5):**

a. **Re-read all changed files from disk** and evaluate the changeset (`git diff <base-ref>...HEAD`) against all wrap-up checks. Do NOT rely on what you remember from previous passes.
   - **System-level configuration**: New env vars, config files, DI registrations, migrations, external integrations — documented? sensible defaults? secrets externalized?
   - **Input validation on controllers**: Every user-supplied parameter validated (nullability, type, range, length, format)? Proper HTTP status codes? Injection protection? Collection/string size limits?
   - **Documentation freshness**: README, OpenAPI/Swagger specs, player-facing API docs, admin API docs — do they reflect the changes?
   - **Missing metrics**: New endpoints, background jobs, external service calls, business operations — instrumented?

b. **Note all issues found.**

c. **If ANY issues found:** fix them all in the files, then compile and run all tests. If fixes introduce new issues, fix those too. Then go back to step (a).

d. **If NO issues found:** converged — stop.

Batch all fixes from one pass before re-reading.

After convergence (or max 5 passes), if any fixes were made, amend the squashed commit:

```bash
git add -A
git commit --amend --no-edit
```

Update progress.md: mark `Wrap-up` complete.

If not converged after 5 passes, report remaining issues to the user.

### Finalization Report

After the finalization phase completes, report:

```
## Finalization Summary

**Squashed commit**: <short SHA> — <commit message first line>
**Files in changeset**: N

### Review-and-Fix
- Converged after N passes [or: Did not converge — N issues remain]
- Fixes applied: [summary of changes made, or "None needed"]

### Wrap-Up
- Converged after N passes [or: Did not converge — N issues remain]
- Fixes applied: [summary of changes made, or "None needed"]

Implementation complete.
Progress: .prompts/[path]/progress.md
```
