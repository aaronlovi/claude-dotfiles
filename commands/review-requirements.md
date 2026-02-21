---
description: "Cross-document consistency review for requirements and Jira tasks"
argument-hint: <requirements-dir>
---

You are a meticulous quality reviewer performing a consistency audit across all requirements and Jira task documents. Your job is to find and fix every inconsistency, gap, and ordering issue.

## Input

$ARGUMENTS should be the path to the requirements directory (e.g., `docs/generalized-requirements/`). If empty, look for `docs/generalized-requirements/` first, then `docs/requirements/` (this command can review either generalized or project-specific requirements). If the target path does not exist, stop and tell the user.

## Prerequisites

**Required:** At minimum, the requirements directory must contain business requirements, technical requirements, and at least one Jira task file. If the Jira task files reference OBS-* or K6-* IDs, the observability requirements document (`technical-requirements.observability-and-testing.md`) must also be present. If any of these are missing, stop and tell the user which documents are needed.

**Optional (enrich review if present):**
- **DDD analysis**: Prefer the generalized version (`docs/generalized-requirements/ddd-analysis.md`) if it exists; fall back to the original (`docs/ddd-analysis.md`). Verify that ubiquitous language terms are used consistently in requirements and Jira tasks. Verify that bounded contexts align with service decomposition. Verify that state machines from the DDD analysis are fully covered by requirements. If using the original (non-generalized) DDD analysis, expect and tolerate terminology divergences documented in the traceability appendices.
- **Service decomposition** (`docs/generalized-requirements/service-decomposition.md`): Verify cross-service dependencies are consistent between the decomposition document and Jira task documents.
- **Flow catalog** (`docs/generalized-requirements/flow-catalog.md` or `docs/requirements/flow-catalog.md`): Verify requirement coverage and terminology consistency.

## Agent Teams Mode (Optional)

Before starting, check if agent teams are enabled by running: `echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

If the value is `1`, use agent teams to parallelize the review checks. Otherwise, skip this section and execute all checks sequentially as a single agent.

### Team Topology

Create a team called `review-requirements` with 3 teammates:

| Teammate | Checks | Rationale |
|---|---|---|
| `coverage-reviewer` | 1 (Requirement ID Integrity), 2 (Coverage Matrix), 4 (Phase Assignment), 11 (Flow Catalog Consistency) | All about requirement ↔ task/flow traceability |
| `dependency-reviewer` | 3 (Dependency Graph), 8 (Implementation Ordering), 10 (Task Independent Testability) | Dependency structure and task granularity |
| `consistency-reviewer` | 5 (Metric Naming), 6 (Cross-Service References), 7 (DDD Alignment), 9 (Framework-Agnostic Language) | Cross-cutting consistency checks |

### Coordination

1. **Lead reads all documents** first and shares the list of file paths with each teammate.
2. **Spawn all 3 teammates** in parallel. Each teammate reads the documents independently and runs their assigned checks.
3. **Each teammate reports findings** in the format specified in the Output section.
4. **Lead merges findings** into a single numbered findings list, deduplicating any overlapping issues.
5. **Lead applies all fixes** in the prescribed order (IDs → coverage → dependencies → rest).
6. **Lead enters the convergence loop** (see Convergence Loop section) — spawning read-only verification subagents that report issues, with the lead applying fixes between passes, until clean or max 5 passes.

Each teammate should be spawned as a `general-purpose` subagent with a clear prompt listing: the document paths, which checks to run (copy the full check descriptions), and the output format. If a teammate fails or returns incomplete results, the lead should complete those checks directly rather than re-spawning.

---

## Process

Read ALL documents in the requirements directory (and any prerequisite documents above). Then perform these checks:

### Check 1: ID Integrity

For every ID referenced in ANY document, verify it exists in the corresponding source document:

| ID Prefix | Defined In |
|-----------|-----------|
| BR-* | `docs/requirements/business-requirements.md` |
| TR-* | `docs/requirements/technical-requirements.md` |
| GBR-* | `docs/generalized-requirements/business-requirements.md` |
| GTR-* | `docs/generalized-requirements/technical-requirements.md` |
| OBS-* | `docs/generalized-requirements/technical-requirements.observability-and-testing.md` |
| K6-* | `docs/generalized-requirements/technical-requirements.observability-and-testing.md` |
| {SVC}-{###} | `docs/generalized-requirements/jira-tasks.{service}.md` (e.g., IAM-001, CSH-001). Task IDs use zero-padded 3-digit numbers. |

When reviewing non-generalized documents (`docs/requirements/`), only validate BR-* and TR-* prefixes. OBS-*, K6-*, and GBR-*/GTR-* prefixes only apply to generalized document sets.

Also validate OBS-* and K6-* references in `jira-checklist.observability.md` (if it exists) against the observability requirements document.

For each ID:
- Verify the ID exists in the corresponding requirements document.
- Verify the requirement text matches what the task describes.
- Flag any ID referenced in a task but missing from the requirements.
- Flag any requirement that exists but is not referenced by any task.

### Check 2: Coverage Matrix Completeness

Across all coverage matrices in all Jira task documents:
- Every requirement ID from the requirements documents (including `technical-requirements.observability-and-testing.md` for OBS-* and K6-* IDs) must appear in at least one coverage matrix (for multi-service architectures, a requirement appears in the service it is assigned to).
- The "Covered By" column must reference valid task IDs from the same service's task document.
- The task IDs listed must actually reference that requirement in their "Requirements covered:" header field. Description-only references are insufficient.

### Check 3: Dependency Graph Consistency

For each Jira task document, verify THREE representations match:
1. **Dependency graph** (Mermaid `graph TD` diagram): visual parent-child relationships
2. **Task header** ("Blocked by:" field): explicit dependency list
3. **Summary table** ("Blocked By" column): tabular dependency list

All three must agree. If the graph shows Task A → Task B, then Task B's header and summary table must list Task A.

Also check:
- No circular dependencies.
- No task depends on a task in a later phase (dependencies flow forward).
- Tasks shown as parallel in the graph have no dependency between them.

### Check 4: Phase Assignment Consistency

- Requirements in business/technical documents have phase assignments.
- Jira tasks have phase assignments.
- The Jira task's phase assignment is authoritative (it reflects full dependency analysis). If a requirement's phase differs from its covering task's phase, update the requirement's phase to match the task, not vice versa.
- Flag any requirement whose phase doesn't match its covering task's phase.
- If the requirements documents do not include explicit `**Phase:**` fields (possible for pre-generalization `docs/requirements/` documents), skip this check and note: "Phase assignment check skipped — requirements documents do not include phase fields."

### Check 5: Metric Naming Consistency

Collect all metric names from:
- Jira task acceptance criteria
- Observability requirements document (service-specific metrics appendix)
- Technical requirements (any GTR-* observability requirements or OBS-* metrics from the observability document)

Verify:
- Same metric name is used everywhere it's referenced.
- No two different names for the same metric.
- Naming follows the convention established in the observability requirements document. If no convention is defined, flag this as a finding.

### Check 6: Cross-Service Reference Consistency

For cross-service dependencies:
- If Service A's task references Service B's task (e.g., "CSH-019 publishes, BON-006 consumes"), verify both sides document the dependency.
- Cross-service dependency tables should be consistent across service documents.
- External dependency tables in requirements documents should match what the Jira tasks describe.

### Check 7: DDD Analysis Alignment (if a DDD analysis exists)

Prefer the generalized DDD analysis (`docs/generalized-requirements/ddd-analysis.md`) if it exists; fall back to the original (`docs/ddd-analysis.md`). If using the original, expect and tolerate terminology divergences documented in the traceability appendices.

- Every ubiquitous language term used in requirements and Jira tasks matches the DDD glossary. Focus on terms that appear in requirement titles and Jira task titles. Description-body synonyms are acceptable if the title uses the canonical DDD glossary term. Flag only exact mismatches (e.g., "user account" in requirements vs. "account" in DDD glossary), not stylistic variations.
- Every state machine in the DDD analysis is covered by at least one requirement and one Jira task.
- Service boundaries in the decomposition document align with bounded contexts in the DDD analysis (or divergences are documented).
- Aggregate boundaries are respected in task scoping (no single task modifies multiple aggregates without justification).

### Check 8: Implementation Ordering

Verify the implementation order makes sense:
- Can each task actually be started once its dependencies are complete?
- Are there tasks that could be parallelized but are shown as sequential? (Flag as optimization opportunity.)
- Is the critical path reasonable?

### Check 9: Framework-Agnostic Language

This check operates at two levels: **terminology** (individual terms) and **architecture** (entire requirements or acceptance criteria that encode framework-specific patterns).

#### 9a: Terminology Scan

Scan ALL generalized documents (requirements, Jira tasks, service decomposition, flow catalog) for implementation/framework-specific terms that should have been generalized. Flag any occurrence of:
- **Language-specific class/interface names**: Interface naming conventions like `IFoo`/`IBar`, generic type syntax like `Task<T>` or `List<T>`, language-specific base classes.
- **Framework component names**: e.g., "Kestrel", "EF Core", "DbContext", "Hibernate", "Express", "Spring Boot", "NestJS", "Rails", "ASP.NET Core".
- **Framework-specific patterns**: e.g., "Options pattern", "middleware pipeline" (when referring to a specific framework's middleware), "hosted service" (when referring to a specific framework's background task model), "DI container with named registrations".
- **Library-specific APIs**: e.g., "JwtBearerHandler", "IServiceCollection", "DbSet<T>", "ApplicationBuilder".
- **Language-specific naming conventions**: PascalCase property names (e.g., "ConfigurationId") that reflect a specific language's style, "I"-prefixed interface names.
- **Runtime-specific concurrency terms**: e.g., "shared cancellation", "cancellation token", "goroutine pool" — terms that name a specific runtime's concurrency mechanism rather than the behavior it provides.

For each flagged term, recommend the language-agnostic equivalent (using the mapping conventions from `/generalize-requirements` Phase 2). This check catches terms that slipped through `/generalize-requirements` or were reintroduced during `/generate-jira-tasks`.

**Do not flag:**
- Generic industry terms that happen to also be framework names (e.g., "middleware" as a general architectural concept is fine; "ASP.NET Core middleware pipeline" is not).
- Pattern names that are language-agnostic (e.g., "repository pattern", "unit of work pattern", "event sourcing").

#### 9b: Architectural Pattern Scan

For each requirement and each Jira task acceptance criterion, apply this test: *"Could a developer implement and test this as-written in Elixir (BEAM), Java (JVM), and Go — not just in the original source language?"* If the answer is no, the requirement encodes a framework-specific architectural pattern regardless of whether it uses framework-specific keywords. Flag it and recommend rewriting in terms of the underlying need.

Common patterns to flag:
- **Manual memory/GC management** (e.g., "trigger garbage collection when memory exceeds threshold"). This is a .NET-specific workaround; BEAM does per-process GC, JVM GC is not application-controlled, Go has its own GC strategy. Recommend: remove, or replace with a performance SLA if the underlying concern is latency under load.
- **Framework-specific hosting models** (e.g., "dual-host architecture with service host and metrics host linked by shared cancellation"). Recommend: "health check and metrics endpoints available on a configurable port" — leave hosting architecture to the implementation team.
- **Prescriptive configuration layering** (e.g., "configuration loads in order: base file, environment-specific file, seed data files, env vars, external provider with poll interval"). This is the exact ASP.NET Core ConfigurationBuilder chain. Recommend: "configuration supports environment-specific overrides and optional external configuration sources."
- **DI container implementation details** (e.g., "DI container with named/keyed registrations", "scoped service lifetime"). Not all languages use DI containers (Elixir and Go typically do not). Recommend: remove — describe the dependency architecture, not the wiring mechanism.
- **Serialization as a task** (e.g., "configure JSON serialization for all API responses"). Every modern framework serializes JSON by default. Recommend: remove unless there are specific serialization rules (date formats, enum handling, null behavior).
- **Runtime-specific background processing** (e.g., "memory monitoring background service at configurable interval"). If the underlying need is runtime-specific (GC tuning), remove it. If the need is universal (e.g., "periodic cleanup of expired tokens"), keep the need but remove the runtime-specific mechanism.

### Check 10: Task-Independent Testability

For each Jira task, verify that its acceptance criteria — especially integration and functional tests — can pass using only the deliverables from that task and its declared dependencies (the "Blocked by" chain). Flag tasks where:

- **The task produces empty infrastructure**: It creates database schemas, data access modules, or repository layers, but the entities or seed data that would make them testable are in a separate downstream task. Integration tests against empty structures are not meaningful.
- **The task produces inert abstractions**: It defines interfaces/contracts and registration mechanisms, but the first concrete implementation is in a different task. There is nothing to test beyond compilation.
- **The task produces wiring without behavior**: It sets up request pipelines, routing, or middleware, but the first endpoint or handler that exercises the pipeline is in another task.

For each flagged task, recommend merging it with the first downstream task that populates or exercises it, creating the smallest unit that produces testable behavior. (This mirrors the validation in `/generate-jira-tasks` Phase 6.5 — this check catches cases that slipped through initial generation or were introduced by edits.)

### Check 11: Flow Catalog Consistency (if a flow catalog exists)

If a flow catalog exists in the requirements directory, verify:
- All requirement IDs in the flow catalog's Requirement Coverage section exist in the requirements documents.
- Every BR-* (or GBR-*) requirement appears in the Covered Requirements or Uncovered Requirements subsection. Every TR-* (or GTR-*) requirement appears in Covered Requirements or System-Wide Constraints.
- All requirement IDs referenced in flow Overview tables and Error Path tables are valid.
- Flow catalog terminology matches generalized requirements terminology (for generalized flow catalogs).
- If flows are referenced in Jira task descriptions, verify each referenced flow exists in the flow catalog. Do not flag tasks that don't reference flows.
- The Uncovered Requirements section is consistent with the Jira task coverage matrix (requirements uncovered by flows may still be covered by tasks, but flag any requirement uncovered by both).

If no flow catalog exists, skip this check.

## Output Format

Write findings to `docs/generalized-requirements/review-findings.md` (or `docs/requirements/review-findings.md` if reviewing non-generalized documents). The file should contain these sections in order: `## Findings` (numbered list), then `## Convergence Log` (pass tracking table).

Report findings as a numbered list:

```
## Findings

### Issue N: {Short description}

- **File:** {file path}
- **Location:** {line number or section}
- **Problem:** {what's wrong}
- **Fix:** {what should change}
```

After reporting ALL findings, apply fixes in a single pass in this order:
1. ID/numbering issues (Check 1)
2. Coverage matrix gaps (Check 2)
3. Dependency graph inconsistencies (Check 3)
4. Remaining issues (Checks 4-11)

If no issues are found, report: "All documents are consistent. No issues found." and stop.

## Convergence Loop

The convergence loop uses Task tool subagents regardless of whether agent teams mode is enabled. This is separate from the agent teams parallelization above — agent teams parallelize the initial review, while convergence subagents handle iterative verification. The convergence subagents are essential for context window management.

After applying fixes, the documents must be verified to confirm no new inconsistencies were introduced. Fixes often cascade — renumbering an ID breaks coverage matrices, fixing a dependency graph misaligns a summary table, etc. A single pass is rarely enough.

**Do NOT re-run all 11 checks in the current context.** Each verification pass reads all documents from scratch, which rapidly exhausts the context window. Instead, use fresh subagents for verification:

### Verification Procedure

After the initial review + fix pass:

1. **Spawn a verification subagent** using the Task tool (`general-purpose` subagent). Give it:
   - The list of all document file paths
   - The full text of all 11 checks (copy from the Process section above)
   - The output format
   - These instructions: "Read all documents. Run all 11 checks. For verification passes 2+, prioritize Checks 1-3 (IDs, coverage, dependencies) which are most likely to drift from fixes; only run Checks 4-11 if Checks 1-3 are clean. If issues are found, report ALL findings in the standard format (Issue N: description, File, Location, Problem, Fix) and respond with `STATUS: ISSUES_FOUND` and the findings list. Do NOT apply fixes — only report them. If no issues are found, respond with `STATUS: CLEAN`."

2. **Check the subagent's response:**
   - `STATUS: CLEAN` → convergence reached. Write final findings to the review-findings file. Report: "Review complete. Converged after N passes."
   - `STATUS: ISSUES_FOUND` → the **lead** applies fixes in the prescribed order (IDs → coverage → dependencies → rest), then spawns another verification subagent (go to step 1). Only the lead edits documents — verification subagents are read-only reporters.

3. **Safety valve:** Maximum 5 verification passes. If not converged after 5, write the remaining issues to the review-findings file and report: "Review did not fully converge after 5 verification passes. N issues remain — see review-findings.md. These likely indicate a structural problem that requires manual intervention."

### Convergence Tracking

Append a convergence log to the review-findings file:

```
## Convergence Log

| Pass | Issues Found | Issues Fixed | Status |
|------|-------------|-------------|--------|
| 1 (initial) | 12 | 12 | Fixed (lead) |
| 2 (verification) | 3 | 3 | Fixed (lead) |
| 3 (verification) | 0 | 0 | Clean |

Converged after 3 passes.
```

## Important

- Read EVERY document before reporting findings. Don't report partial results.
- Report ALL findings first, then apply fixes in a single ordered pass. Do not fix as you go — cascading fixes can introduce new inconsistencies.
- Before applying the initial fix pass, create a summary of all documents that will be modified so the user can review the scope of changes afterward.
- Always use the convergence loop. Never stop after the initial fix pass without at least one verification subagent confirming the documents are clean.
- Pay special attention to summary tables — they're the most common source of drift from the detailed task descriptions.
- If Check 7 finds inconsistencies between the DDD analysis and requirements, flag them as findings but do NOT modify the DDD analysis document — it is produced by a separate pipeline stage.
- If Check 6 finds inconsistencies between the service decomposition and Jira task documents, fix the Jira task documents to match the service decomposition — the decomposition is authoritative for service boundaries and assignments.
- For Check 4 phase conflicts, the authoritative rule is defined inline in Check 4 above.
- **Next step**: This is the final pipeline stage. Re-run after any document changes to verify consistency. See `/pipeline` for the full stage list.
