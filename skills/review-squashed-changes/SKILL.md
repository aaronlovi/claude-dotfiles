---
name: review-squashed-changes
description: Review all code changes in a squashed commit on top of origin/main
allowed-tools: Read, Glob, Grep, Bash(git diff*), Bash(git log*), Bash(git show*), Bash(git status*), Bash(git rev-parse*), Bash(git merge-base*), Task
argument-hint: [base-ref]
user-invocable: true
---

# Review Squashed Changes

Review all code changes in a squashed commit sitting on top of a base branch.

**Base ref**: `$ARGUMENTS` (defaults to `origin/main` if empty)

## Prerequisites

1. Run `git status` to check for uncommitted changes. If the working tree is dirty, stop and tell the user: "Please commit or stash your changes before running this review."
2. Run `git diff <base-ref>...HEAD --stat` to confirm there are changes to review. If there are zero changes, stop and tell the user: "No changes found between HEAD and `<base-ref>`."

## Process

### 1. Gather the diff

```bash
git diff <base-ref>...HEAD --name-status
```

Categorize every changed file into:
- **Production code**: all non-test source files
- **Test files**: files matching common test patterns (`*test*`, `*spec*`, `*Test*`, `*_test.*`, `*.test.*`, `*.spec.*`, `tests/`, `__tests__/`, etc.)
- **Non-code**: config, docs, scripts, lock files, etc.

Report the file list to the user grouped by category before starting the review.

### 2. Review production code changes

For each production code file, read the **diff hunks** (not the full file — focus on what changed):

```bash
git diff <base-ref>...HEAD -- <file>
```

Evaluate each file's changes against these criteria:

- **Correctness**: Logic errors, off-by-one, null/undefined handling, missing error paths, race conditions.
- **Security**: Injection risks (SQL, command, XSS), hardcoded secrets, improper auth checks, unsafe deserialization.
- **API contract**: Breaking changes to public interfaces, missing validation on inputs, changed return types or shapes.
- **Edge cases**: Boundary conditions, empty collections, missing defaults, integer overflow.
- **Resource management**: Unclosed handles, missing cleanup, unbounded allocations, connection leaks.
- **Naming and clarity**: Misleading names, overly clever code, unexplained magic numbers.

Do NOT flag:
- Style preferences (formatting, whitespace, import order) — assume a formatter handles this.
- Missing documentation or comments on self-explanatory code.
- Pre-existing issues in unchanged code.

### 3. Review test files (full-file review)

For each test file that was added or modified, read the **entire file** (not just the diff):

```bash
git show HEAD:<file>
```

Evaluate the full test file against these criteria:

#### 3a. Correctness of tests
- Do tests actually assert what they claim to test?
- Are assertions specific enough (not just "no error thrown")?
- Do tests cover both happy path and error cases for the code they exercise?
- Are there tests that will always pass regardless of implementation (tautological tests)?

#### 3b. Don't Repeat Yourself (DRY)
- Are there groups of tests with near-identical setup, act, or assert blocks?
- Could repeated setup be extracted to shared fixtures, helpers, or `beforeEach`/`setUp` blocks?
- Are there duplicated assertion patterns that could become a custom matcher or helper?

#### 3c. Data-driven test opportunities
- Are there multiple tests that differ only in input values and expected outputs?
- These should be refactored to parameterized / table-driven / `theory` / `test.each` style tests.
- Suggest the specific data-driven mechanism appropriate to the test framework in use.

#### 3d. Other refactoring opportunities
- Overly long test methods that test multiple behaviors (should be split).
- Test names that don't describe the scenario and expected outcome.
- Brittle tests coupled to implementation details rather than behavior.
- Missing boundary value tests that the data-driven format would naturally accommodate.

### 4. Review non-code files (light pass)

For config, CI, scripts, and similar files — skim the diff for:
- Hardcoded secrets or credentials.
- Obviously wrong values (wrong environment, wrong paths).
- Changes that contradict other files in the changeset.

Skip detailed review for lock files, generated files, and vendored dependencies.

### 5. Cross-cutting concerns

After reviewing individual files, consider the changeset as a whole:
- **Consistency**: Do the production code changes and test changes align? Is there new code without corresponding tests?
- **Completeness**: Are there obvious gaps — e.g., a new public function with no test, or error handling added in one place but not a similar adjacent place?
- **Architectural fit**: Do the changes follow the patterns established in the rest of the codebase, or do they introduce a divergent approach?

## Parallelization

If there are more than 5 changed files, use Task tool subagents to parallelize the review:

- Group files into batches (aim for 3-5 files per agent, keeping related files together).
- Spawn one `general-purpose` subagent per batch. Give each agent the base ref, its file list, and the relevant review criteria (production code criteria for code files, full-file test criteria for test files).
- Each agent returns its findings as a list (file, line(s), severity, description).
- The lead merges and deduplicates findings, then performs the cross-cutting review (step 5).
- The lead then runs the Review Verification Loop on the merged findings.

For 5 or fewer files, review sequentially in the current context.

## Review Verification Loop (Mandatory Convergence)

After the initial review (steps 1-5, including cross-cutting), you MUST execute this iterative loop — do NOT skip it or do a single mental check:

**For each pass (max 5):**
1. **Re-read the source files from disk** for every finding you reported. Do NOT rely on what you remember reading — the file on disk is the source of truth.
2. **Evaluate every finding against these criteria:**
   - **Accuracy**: Re-read the surrounding code context. Is the finding still valid, or did you misread the code? Drop false positives.
   - **Completeness**: While re-reading, did you spot any issues you missed on the first pass? Add them.
   - **Severity**: Is the severity level (Critical / Improvement / Test Refactoring / Nitpick) appropriate given the full context?
3. **If ANY findings changed** (added, removed, or re-categorized): update your findings list, then go back to step 1 (re-read from disk again).
4. **If NO findings changed:** the review is stable. Stop.

Batch all changes from one pass before re-reading. If still changing after 5 passes, stop and append a note to the review summary listing which findings are still unstable.

## Output Format

After the verification loop completes, report the final findings grouped by severity:

```
## Review Summary

**Base**: <base-ref>
**Commit**: <short SHA> — <commit message first line>
**Files reviewed**: N production, N test, N non-code
**Verification**: Converged after N passes [or: N findings still unstable after 5 passes]

## Findings

### Critical
Issues that are very likely bugs or security vulnerabilities.

### Improvement
Concrete suggestions to improve correctness, maintainability, or test quality.

### Test Refactoring
DRY, data-driven, and other refactoring opportunities in test files.

### Nitpick
Minor observations. Include only if genuinely useful.
```

Within each severity section, format each finding as:

```
- **<file>:<line(s)>** — <description>
  <brief code snippet or diff excerpt if it clarifies the issue>
```

If no findings in a severity section, omit that section.

If there are zero findings overall, report: "No issues found. The changeset looks good."

## After Review

Report the final findings to the user. Do not modify any files — this is a read-only review.
