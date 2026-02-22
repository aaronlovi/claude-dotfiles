---
name: wrap-up
description: Final sweep of a completed task — checks for loose ends and fixes them
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, AskUserQuestion
argument-hint: [base-ref]
user-invocable: true
---

# Wrap Up

Final sweep before considering a task done. Identifies loose ends in the changeset and fixes them.

**Base ref**: `$ARGUMENTS` (defaults to `origin/main` if empty)

## Prerequisites

1. Run `git diff <base-ref>...HEAD --stat` to confirm there are changes to review. If there are zero changes, stop and tell the user: "No changes found between HEAD and `<base-ref>`."

## Gather Context

Before starting the checks, gather the changeset:

```bash
git diff <base-ref>...HEAD --name-only
```

Read the project's `CLAUDE.md` (if it exists) to understand conventions, test commands, and documentation locations.

## Checks

Evaluate the changeset against every check below. For each check, read the relevant files from disk — do NOT rely on memory from earlier in the conversation.

### Check 1: System-level configuration

Identify any system-level configuration that was added or changed in this task:
- New environment variables, feature flags, or app settings
- New configuration files or sections (appsettings, .env, YAML configs, etc.)
- New dependency injection registrations, middleware, or service wiring
- Database migrations or schema changes
- New external service integrations or connection strings

For each item found:
- Is it documented? (README, deployment docs, or inline comments explaining the knob)
- Are there sensible defaults for local development?
- Are secrets or credentials properly externalized (not hardcoded)?

### Check 2: Input validation on controllers

For every controller method (or API endpoint handler) that was introduced or modified in the changeset:
- Read the full method, not just the diff.
- Is every user-supplied parameter validated? (nullability, type, range, length, format)
- Are validation errors returned as appropriate HTTP status codes (400, 422) with useful messages?
- Is there protection against common injection vectors for the parameter type?
- For collection parameters: are there reasonable size limits?
- For string parameters: are there reasonable length limits?

### Check 3: Documentation freshness

Determine which documentation may need updating based on the changeset:

- **README.md**: Does the changeset add new setup steps, dependencies, environment variables, or fundamentally change how the project runs?
- **OpenAPI / Swagger**: If the project uses OpenAPI specs (look for `swagger`, `openapi`, `.yaml`/`.json` API specs, or Swashbuckle/NSwag/springdoc config), do the specs reflect any new or changed endpoints, request/response shapes, or status codes?
- **Player-facing API docs**: If separate API documentation exists for external consumers, does it cover new or changed endpoints?
- **Admin API docs**: Same check for internal/admin API documentation.

For each documentation gap found, make the update directly. If you cannot determine the correct content, flag it for the user instead of guessing.

### Check 4: Missing metrics

Review the changeset for operations that should be instrumented but aren't:
- New API endpoints without request count / latency / error rate metrics
- New background jobs or queue consumers without processing metrics
- New external service calls without call count / latency / error rate metrics
- New business-critical operations without domain-specific metrics (e.g., payments processed, users registered)
- Error paths that swallow exceptions without incrementing an error counter

Add the metrics directly, following the naming conventions and instrumentation patterns already established in the codebase. If no convention exists or the instrumentation framework is unclear, flag it for the user rather than guessing.

## Fix-and-Verify Loop (Mandatory Convergence)

After the initial evaluation, you MUST execute this iterative loop — do NOT skip it or do a single mental check:

**For each pass (max 5):**
1. **Re-read from disk** all files in the changeset (relative to the base ref) plus any files you modified during previous fix passes. Do NOT rely on what you remember writing — the file on disk is the source of truth.
2. **Evaluate the changeset against every check above.** Note all issues found.
3. **If ANY issues found:** fix them all in the files, then compile the project and run the test suite. If compile errors or test failures result from your fixes, fix those too before proceeding. Then go back to step 1 (re-read from disk again).
4. **If NO issues found:** the changeset is clean. Stop.

Batch all fixes from one pass before re-reading. Fixes may introduce new issues (e.g., adding validation might need a new test, adding a metric might need a new config entry), so always re-read and re-evaluate after fixing. If still changing after 5 passes, stop and report remaining issues to the user.

## Output

After the loop completes (converged or max passes), report a summary:

```
## Wrap-Up Summary

**Base**: <base-ref>
**Changeset**: N files

### Configuration
- [items found and documented, or "No new configuration added"]

### Input Validation
- [fixes applied, or "All controller inputs validated"]

### Documentation
- [updates made, or "No documentation updates needed"]

### Metrics
- [metrics added, or "No missing metrics identified"]

### Convergence
Converged after N passes. [or: Did not converge after 5 passes — N issues remain.]
```

If not converged, list the remaining issues after the summary so the user can address them manually.
