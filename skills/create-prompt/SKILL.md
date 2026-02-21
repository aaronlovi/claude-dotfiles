---
name: create-prompt
description: Create a task prompt when the work is clear and ready to implement
allowed-tools: Read, Glob, Grep, Write, Bash(ls*), Bash(mkdir*), AskUserQuestion
argument-hint: <task description>
user-invocable: true
---

# Create Prompt

Create a prompt for a well-defined task that's ready to implement.

**Task**: $ARGUMENTS

If `$ARGUMENTS` is empty or vague, ask the user: "What task do you want to create a prompt for?" Do not proceed until you have a clear task description.

Use this when:
- The task is clear and scoped
- You understand what needs to be built
- No research phase needed

If the task needs exploration first, use `/create-meta-prompt` instead. Heuristic: if you need to read more than 5 files to understand the scope, or if there are multiple viable approaches, redirect to `/create-meta-prompt`.
If a dedicated slash command exists for the task type (e.g., `/ddd-analysis`, `/extract-requirements`), use that instead of creating a prompt. See `/pipeline` for the complete list of pipeline commands.

## Steps

1. **Read project context**
   - `CLAUDE.md` (required if exists)
   - `README.md`
   - Relevant source files: read files directly referenced in the task description. If the task mentions a module or feature, read its entry point and up to 3 related files. Do not exhaustively explore — use `/create-meta-prompt` if broader exploration is needed.

2. **Clarify if needed** (1-2 questions max)
   - What does success look like?
   - Any constraints or preferences?
   - Skip if obvious from context

3. **Design checkpoints**
   - Break work into incremental steps
   - Each checkpoint: implementation + unit tests for that checkpoint's code
   - All existing + new tests must pass at the end of each checkpoint
   - Each should be reviewable/commitable independently
   - NEVER put a dedicated "testing" checkpoint at the end — tests are written alongside the code they verify
   - Exception: a checkpoint that is purely non-code work (documentation, configuration) does not need tests
   - Target 3-7 checkpoints. If more than 7 are needed, the task may be too large — consider splitting into multiple prompts or using `/create-meta-prompt` for better planning.

4. **Write prompt** to `.prompts/NNN-name.md` (use lowercase-hyphenated format for the name, e.g., `001-add-user-validation.md`). Create `.prompts/` directory if it doesn't exist.

   **Important**: Do NOT use names ending in `-research` or `-plan` — these suffixes are reserved for meta-prompt directories and would cause ambiguity in `/run-prompt` resolution.

## Prompt Template

```markdown
# [Task Name]

## Objective
[What to build and why - 1-2 sentences]

## Context
- Guidelines: `CLAUDE.md`
- Key files: [relevant paths]
- Stack: [if relevant]

## Checkpoints

### 1. [First increment]
- Build: [what to implement]
- Test: [unit tests for the code in this checkpoint]
- Verify: [all tests pass]

### 2. [Second increment]
- Build: [what to implement]
- Test: [unit tests for the code in this checkpoint]
- Verify: [all tests pass]

[Continue as needed - prefer smaller checkpoints. Never have a testing-only checkpoint at the end.]

## Verification
[Test command from CLAUDE.md, e.g., `npm test`, `dotnet test`]

## Done When
[Clear success criteria]
```

## Numbering

```bash
ls .prompts/[0-9][0-9][0-9]-*.md 2>/dev/null | sort | tail -1
```
Increment highest number, or start at `001`. Always zero-pad to 3 digits. The glob `[0-9][0-9][0-9]-*.md` ensures only numbered task prompts are matched, excluding progress files and non-numeric filenames.

## Self-Review (Mandatory Convergence Loop)

After writing the prompt, you MUST execute this iterative loop — do NOT skip it or do a single mental check:

**For each pass (max 5):**
1. **Re-read the prompt from disk** using the Read tool. Do NOT rely on what you remember writing — the file on disk is the source of truth.
2. **Evaluate against every criterion below.** Note all issues found.
3. **If ANY issues found:** fix them all in the file, then go back to step 1 (re-read from disk again).
4. **If NO issues found:** the prompt is stable. Append `<!-- Self-review: converged after N passes -->` to the file and stop.

Batch all fixes from one pass before re-reading. If still changing after 5 passes, stop and note remaining issues under `## Self-Review Notes`.

**Criteria:**
- **Consistency**: Checkpoint descriptions use parallel structure; context section matches actual project files; verification commands match CLAUDE.md
- **Correctness**: Checkpoints are in a buildable order (no forward references); each checkpoint's tests cover its own code; no dedicated testing checkpoint at the end
- **Information density**: Enough detail for an LLM to implement without guessing, but no redundant restatements or filler. If a checkpoint says "implement X" but doesn't say *how* or *where*, add specifics. If it over-explains something obvious, trim it.

## After Saving

Say: "Created `.prompts/NNN-name.md` with N checkpoints. Run with `/run-prompt NNN` or review first."

Task prompts do not include a metadata block (metadata is only for research.md/plan.md).
Progress will be tracked in `.prompts/NNN-name.progress.md` during execution.
