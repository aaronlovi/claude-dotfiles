# Self-Review Convergence Protocol

This protocol is referenced by pipeline commands (Stages 1-6) to iteratively refine artifacts until stable. It is NOT a standalone command. Stage 7 (`review-requirements`) has its own convergence loop for multi-document cross-consistency review — this protocol does not apply to it. Prompt skills (`/create-prompt`, `/create-meta-prompt`, `/run-prompt`) follow equivalent inline loops and do not reference this file.

## Procedure

After producing the output artifact, iterate until idempotent (no changes needed):

1. **Re-read your output from disk** using the Read tool. Do NOT rely on what you remember writing — the file on disk is the source of truth.

2. **Evaluate against all quality criteria** defined in the calling command's or skill's self-review section. Check for:
   - Internal consistency (do tables match prose? do IDs cross-reference correctly? does the table of contents match the headings?)
   - Completeness (did you cover everything the command requires?)
   - Formatting (does the output match the specified template?)
   - Correctness (are cross-references to input documents accurate?)

3. **If ANY issues found:** fix them in the artifact, then go to step 1 (re-read from disk again).

4. **If NO issues found:** the artifact is stable. Stop and proceed to the next step indicated by the command.

## Constraints

- **Maximum 5 self-review passes.** If the artifact is still changing after 5 passes, stop and note the remaining issues at the bottom of the artifact under a `## Self-Review Notes` section.
- **Always re-read from disk** before each evaluation pass. Edits may have introduced new issues (e.g., fixing an ID breaks a cross-reference table).
- **Fix all issues found in a pass before re-reading.** Do not re-read after each individual fix — batch all fixes from one evaluation, then re-read to check for cascading effects.

## Context Window Management

- **Single-file artifacts** (most pipeline stages): perform self-review in the current context. The file is small enough to re-read without concern.
- **Multi-file artifacts** (e.g., `generate-jira-tasks` which produces multiple files): use a Task tool subagent (`general-purpose`) for verification passes 2+ to avoid exhausting the context window. Give the subagent the file paths, the quality criteria, and instructions to report `STATUS: CLEAN` or `STATUS: ISSUES_FOUND` with a findings list. The lead applies fixes and spawns fresh subagents for subsequent passes.

## Agent Teams Integration

For commands that support Agent Teams mode: the lead performs self-review after merging all teammate outputs, not during parallel phases. Teammates focus on their assigned scope; the lead owns convergence.

## Tracking

**If converged:** append a brief log to the end of the artifact:

```
<!-- Self-review: converged after N passes -->
```

This is an HTML comment so it doesn't affect document rendering but provides traceability.

**If NOT converged after 5 passes:** add a visible section at the bottom of the artifact listing the remaining issues:

```markdown
## Self-Review Notes
- [remaining issue 1]
- [remaining issue 2]
```
