---
name: create-meta-prompt
description: Create research/plan workflow for complex tasks that need exploration
allowed-tools: Read, Glob, Grep, Write, Bash(ls*), Bash(mkdir*), AskUserQuestion
argument-hint: <task description>
user-invocable: true
---

# Create Meta-Prompt

Create prompts for complex tasks that benefit from research before implementation.

**Task**: $ARGUMENTS

If `$ARGUMENTS` is empty or vague, ask the user: "What task needs exploration? Describe what you want to accomplish." Do not proceed until you have a clear task description.

Use this when:
- Task needs exploration to understand scope
- Multiple approaches are possible
- You need to understand existing code patterns first

If a dedicated slash command exists for the task type (e.g., `/ddd-analysis`, `/extract-requirements`), use that instead of creating a meta-prompt. See `/pipeline` for the complete list of pipeline commands.

Workflow: **Research** → **Plan** → **Implement** (using plan directly)

## Steps

1. **Read project context**
   - `CLAUDE.md` (required if exists)
   - `README.md`

2. **Check for existing workflows**
   ```bash
   ls -d .prompts/*-research .prompts/*-plan 2>/dev/null
   ```
   If any exist, list them and ask: "Continue one of these, or start new?" When checking, also consider whether the user's current task description might match an existing workflow under a different slug name.
   - If continuing: use that slug and proceed to step 4 — the decision table will determine which phase to generate next based on the existing artifacts (research.md, plan.md) in that workflow
   - If new: derive slug from task. If the derived slug matches an existing workflow directory, append a numeric suffix (e.g., `refactor-payment-system-2`) or ask the user for a different name.

3. **Determine slug** (if starting new)
   - Lowercase, hyphenate, drop stopwords (a, an, the, of, for, to)
   - Example: "Refactor the payment system" → `refactor-payment-system`

4. **Determine which phase to generate**

   Parse the `## Metadata` / `### Status` section at the end of `research.md` or `plan.md`. If no Metadata section exists, treat Status as `success`.

   | Condition | Action |
   |-----------|--------|
   | No `research.md` | Generate **research** prompt |
   | `research.md` exists, Status is `partial` or `failed` | Ask user: re-run research or proceed with partial findings? If research.md contains a metadata block but no substantive findings (all questions unanswered or answered with "Could not determine"), recommend re-running with refined questions. |
   | `research.md` exists but is empty or has no substantive content | Treat as if `research.md` does not exist — re-generate research prompt |
   | `research.md` exists, Status is `success` (or no metadata) AND has substantive content, no `plan.md` | Generate **plan** prompt |
   | `plan.md` exists, Status is `partial` or `failed` | Ask user: re-generate plan or implement with current plan? |
   | `plan.md` exists, Status is `success` (or no metadata) | No prompt needed — tell user to implement with `/run-prompt {slug}-plan` |

5. **Generate the prompt** — create the output directory (and `.prompts/` parent if needed) using `mkdir -p`.

## Research Prompt

`.prompts/{slug}-research/prompt.md`:

```markdown
# Research: [task]

## Objective
Understand [what needs to be understood] before implementation.

## Context
- Guidelines: `CLAUDE.md`
- Key files: [relevant paths]
- Stack: [if relevant]

## Questions to Answer
1. [Specific question about the codebase]
2. [Specific question about approach]
3. [Specific question about existing patterns]
4. [Specific question about constraints or risks]

## Explore
- [Key files/directories to examine]
- [What to search for]

## Output
Write findings to `.prompts/{slug}-research/research.md`:
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
```

## Plan Prompt

`.prompts/{slug}-plan/prompt.md`:

```markdown
# Plan: [task]

## Context
- Research: `.prompts/{slug}-research/research.md`
- Guidelines: `CLAUDE.md`

## Instructions
1. Read research.md
2. Design implementation as checkpoints
3. Each checkpoint must include:
   - Build: what to implement
   - Test: what unit tests to write for THIS checkpoint's code
   - Verify: how to confirm all existing + new tests pass before moving on
4. NEVER design a dedicated "testing" checkpoint at the end. Tests are written alongside the code they verify, within the same checkpoint. Each checkpoint must leave the test suite green.

## Output
Write plan to `.prompts/{slug}-plan/plan.md`:
- Ordered checkpoints (implementation + tests each — no checkpoint without tests unless it is purely non-code work like documentation or configuration)
- Files to create/modify
- Metadata block (Status, Dependencies, Open Questions, Assumptions)
```

## After Plan is Complete

No separate "do" prompt is needed. The plan.md contains the checkpoints. User implements by:
- Running `/run-prompt {slug}-plan` (executes the plan)
- Or asking directly: "Implement the plan in `.prompts/{slug}-plan/plan.md`"

Progress will be tracked in `.prompts/{slug}-plan/progress.md` during execution. If interrupted, running the same command again will resume from the last incomplete checkpoint.

## Self-Review (iterate up to 5 times)

After writing the prompt, iterate up to 5 times:
1. Re-read the file you just wrote
2. Check against these criteria:
   - **Consistency**: Context paths match actual project structure; cross-references between research/plan use correct filenames and slugs; output instructions match what `/run-prompt` expects
   - **Correctness**: Research questions are specific and answerable by reading code (not vague "what do you think about X"); plan instructions reference research.md correctly; checkpoint structure follows the template
   - **Information density**: Enough detail for an LLM to execute without guessing, but no redundant restatements or filler. Research questions that overlap should be merged. Explore sections should list concrete paths, not "relevant files."
   - **Prompt-type-specific checks**:
     - If generating a research prompt: verify all Questions are specific and answerable by reading code; verify Explore section lists concrete file paths, not "relevant files."
     - If generating a plan prompt: verify it references the correct `research.md` path; verify the slug in all paths is consistent; verify checkpoint structure instructions match the `/prompt-rules` template.
3. If changes needed — edit the file in place and continue the loop
4. If no changes needed — stop iterating

## After Saving

Report what was created and what's next:
- After research prompt: "Created research prompt. Run with `/run-prompt {slug}-research`, then run `/create-meta-prompt [same task]` again to generate the plan phase."
- After plan prompt: "Created plan prompt. Run `/run-prompt {slug}-plan` to generate the plan. Once the plan is generated, run the same command again to implement it checkpoint by checkpoint."
