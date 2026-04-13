---
name: extract-guidelines
description: Review recent work for lessons learned and propose additions to CLAUDE.md or global rules
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, AskUserQuestion
argument-hint: [base-ref]
user-invocable: true
---

# Extract Guidelines

Review recent changes and conversation context for patterns, fixes, or lessons learned that should be codified as guidelines. Propose additions to the appropriate configuration file.

**Base ref**: `$ARGUMENTS` (defaults to `origin/main` if empty)

## Process

1. **Examine the diff** from the base ref to HEAD:
   ```
   git diff <base-ref>...HEAD --stat
   git log --oneline <base-ref>..HEAD
   ```

2. **Identify guideline candidates** — look for:
   - Bugs caused by inconsistent conventions (e.g., camelCase vs snake_case)
   - Configuration mistakes that were easy to make (e.g., wrong function for env vars)
   - Patterns that were added or corrected (e.g., unique constraints, field naming)
   - Tool setup that should be standard (e.g., dialyzer, linters)
   - Anything that was fixed and could recur if not documented

3. **Categorize each candidate** into one of:
   - **Project CLAUDE.md** — specific to this project's conventions (e.g., "this API uses snake_case")
   - **Global CLAUDE.md** (`~/.claude/CLAUDE.md`) — applies to all projects for this user
   - **Language rules** (`~/.claude/rules/<lang>.md`) — applies to all projects using this language/framework

4. **Check for duplicates** — read the target file and verify the guideline doesn't already exist. If a similar guideline exists but is incomplete, propose updating it instead.

5. **Present findings** — use AskUserQuestion to show the user:
   - What guidelines you'd add
   - Where each one goes
   - The exact text

   Format:
   ```
   ## Proposed Guidelines

   ### 1. [Short title]
   **Target**: [file path]
   **Text**: [the guideline text]
   **Reason**: [what went wrong / what this prevents]
   ```

6. **Apply approved guidelines** — after user approval, write the additions to the appropriate files.

## Guidelines for writing guidelines

- Lead with the rule, then explain why. Future-you needs to judge edge cases.
- Be specific enough to act on. "Be consistent" is not a guideline; "Use snake_case for all JSON API keys" is.
- Don't duplicate what's already in the codebase (e.g., don't write "use Ecto.Multi" if the code already does).
- Don't codify one-off decisions — only patterns that apply broadly.
- Keep each guideline to 1-3 sentences. If it needs more, it's probably documentation, not a guideline.
