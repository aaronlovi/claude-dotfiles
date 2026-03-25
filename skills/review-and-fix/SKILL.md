---
name: review-and-fix
description: Review all code changes in a squashed commit, fix issues found, and iterate until clean (max 5 passes)
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Agent, AskUserQuestion
argument-hint: [base-ref] [max-iterations]
user-invocable: true
---

# Review and Fix

Review all code changes in a squashed commit, fix the issues found, then re-review — repeating until no new issues are found or max iterations reached.

**Base ref**: first word of `$ARGUMENTS` (defaults to `origin/main` if empty)
**Max iterations**: second word of `$ARGUMENTS` (defaults to `5`)

## Prerequisites

1. Run `git status` to check for uncommitted changes. If the working tree is dirty, stop and tell the user: "Please commit or stash your changes before running this skill."
2. Run `git diff <base-ref>...HEAD --stat` to confirm there are changes to review. If there are zero changes, stop and tell the user: "No changes found between HEAD and `<base-ref>`."

## Detect Project Verification Commands

Before starting the loop, determine how to verify the project compiles, passes lint, and passes tests. Check in this order:

1. **CLAUDE.md** — look for documented build/test/lint commands
2. **Project files** — detect automatically:
   - `mix.exs` → `mix compile --warnings-as-errors`, `mix credo`, `mix test`
   - `package.json` → `npm run build` (or `tsc --noEmit`), `npm run lint`, `npm test`
   - `Cargo.toml` → `cargo build`, `cargo clippy`, `cargo test`
   - `go.mod` → `go build ./...`, `golangci-lint run`, `go test ./...`
   - `pyproject.toml` / `setup.py` → project-specific lint/test (look for pytest, ruff, mypy)
3. If unclear, ask the user what commands to run.

Store the three commands as `$COMPILE_CMD`, `$LINT_CMD`, `$TEST_CMD`. Any may be empty if not applicable.

## Main Loop

Execute this loop, starting at iteration 1:

### Step 1: Review

Gather the diff:

```bash
git diff <base-ref>...HEAD --name-status
```

Categorize every changed file into:
- **Production code**: all non-test source files
- **Test files**: files matching common test patterns (`*test*`, `*spec*`, `*Test*`, `*_test.*`, `*.test.*`, `*.spec.*`, `tests/`, `__tests__/`, etc.)
- **Non-code**: config, docs, migrations, scripts, lock files, etc.

On iteration 1, report the file list to the user grouped by category. On subsequent iterations, only report files that changed since the last iteration.

#### Parallelized review with agents

If there are more than 5 changed files, use Agent tool subagents to parallelize the review. Group files into batches (3-8 files per agent, keeping related files together). Spawn agents in parallel.

**Each review agent receives:**
- The base ref
- Its file list and file category (production / test / non-code)
- The review criteria for that category (below)
- Instructions to read the project's `CLAUDE.md` for project-specific coding guidelines
- Instructions to return findings as a structured list: `(file, line(s), severity, description)`

For 5 or fewer files, review sequentially in the current context.

#### Production code criteria

For each production code file, read the **diff hunks** (not the full file — focus on what changed):

- **Correctness**: Logic errors, off-by-one, null/undefined handling, missing error paths, race conditions.
- **Security**: Injection risks (SQL, command, XSS), hardcoded secrets, improper auth checks, unsafe deserialization.
- **API contract**: Breaking changes to public interfaces, missing validation on inputs, changed return types or shapes.
- **Edge cases**: Boundary conditions, empty collections, missing defaults, integer overflow.
- **Resource management**: Unclosed handles, missing cleanup, unbounded allocations, connection leaks.
- **Naming and clarity**: Misleading names, overly clever code, unexplained magic numbers.

Do NOT flag:
- Style preferences (formatting, whitespace, import order) — assume a formatter and linter handle this.
- Missing documentation or comments on self-explanatory code.
- Pre-existing issues in unchanged code.

#### Test file criteria (full-file review)

For each test file, read the **entire file** (not just the diff):

- Do tests actually assert what they claim to test?
- Are assertions specific enough (not just "no error thrown")?
- Do tests cover both happy path and error cases?
- Are there tautological tests (always pass)?
- DRY opportunities: repeated setup, duplicated assertions?
- Data-driven test opportunities: multiple tests differing only in input/output?
- Test names describe scenario and expected outcome?
- Tests coupled to implementation details rather than behavior?

#### Non-code file criteria (light pass)

- Hardcoded secrets or credentials.
- Obviously wrong values (wrong environment, wrong paths).
- Changes that contradict other files in the changeset.
- Migration files: required comments, correct types, proper indexes.

Skip detailed review for lock files, generated files, and vendored dependencies.

#### Cross-cutting concerns

After individual file reviews complete, consider the changeset as a whole:
- **Consistency**: Do production code changes and test changes align? New code without tests?
- **Completeness**: New public function with no test? Error handling added in one place but not a similar adjacent place?
- **Architectural fit**: Do changes follow established patterns or introduce divergent approaches?

### Step 2: Triage findings

After all review agents return, merge and deduplicate findings. Classify each as:

- **Critical** — Very likely bugs, security vulnerabilities, or correctness issues. **Always fix.**
- **Improvement** — Concrete suggestions for correctness, maintainability, or robustness. **Fix unless clearly a design decision.**
- **Test Refactoring** — DRY, data-driven, and refactoring opportunities in tests. **Fix if straightforward; skip if it would require large rewrites.**
- **Nitpick** — Minor observations. **Skip** (do not fix).

Report the findings to the user grouped by severity before fixing.

### Step 3: Fix

If there are no Critical or Improvement findings to fix, skip to Step 5.

Use Agent tool subagents to fix issues in parallel. Group fixes by file (never have two agents editing the same file). Each fix agent receives:
- The file path
- The specific findings to fix (with line numbers and descriptions)
- The project's `CLAUDE.md` coding guidelines
- Instructions to read the file before editing, and to use the Edit tool

### Step 4: Verify

Run the verification commands sequentially:

1. `$COMPILE_CMD` — if it fails, fix compile errors and re-run before proceeding
2. `$LINT_CMD` — if it reports fixable issues, fix them and re-run before proceeding
3. `$TEST_CMD` — if tests fail, diagnose and fix failures, then re-run

If any verification step fails more than 3 times in a row, stop and report the failure to the user.

### Step 5: Check convergence

If this was iteration N and:
- **No findings were reported in Step 2** → Converged. Go to Output.
- **Only Nitpick findings remain** → Converged. Go to Output.
- **N >= max iterations** → Did not converge. Go to Output.
- **Otherwise** → Increment iteration. On subsequent iterations, only re-review files that were modified in Step 3. Go back to Step 1.

## Output

After the loop completes, report:

```
## Review & Fix Summary

**Base**: <base-ref>
**Commit**: <short SHA> — <commit message first line>
**Files reviewed**: N production, N test, N non-code
**Convergence**: Clean after N iterations [or: N findings remain after M iterations]

### Fixes Applied
- [List of fixes applied, grouped by file]

### Remaining Items (not fixed)
- [Design decisions, nitpicks, or items that could not be resolved]
[or: "None — all findings resolved."]
```

If not converged, list remaining issues so the user can address them manually.
