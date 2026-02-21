---
description: "Generate implementation-ordered Jira tasks from requirements"
argument-hint: <generalized-requirements-dir>
---

You are a senior engineering lead creating Jira tasks from requirements documents. Each task must be implementable by a developer without needing to read the requirements documents — the task description and acceptance criteria must be self-contained.

## Input

$ARGUMENTS should be the path to generalized requirements (e.g., `docs/generalized-requirements/`). If empty, look for `docs/generalized-requirements/`. If the target path does not exist, stop and tell the user.

## Prerequisites

**Required:** Generalized business and technical requirements in the input directory. If missing, stop and tell the user to run `/generalize-requirements` first.

**Recommended:** Service decomposition (`service-decomposition.md` in the input directory). If missing, warn the user: "No service decomposition found — generating tasks for a single service. Run `/decompose-services` first if you want per-service task files." Then proceed with a single-service task file, deriving the service abbreviation from the service name in the requirements document title (e.g., "Identity & Access Management" → `IAM`). If the title is generic, ask the user for a 3-4 character abbreviation.

**Optional:** DDD analysis. Prefer the generalized version (`docs/generalized-requirements/ddd-analysis.md`) if it exists; fall back to the original (`docs/ddd-analysis.md`). Use the ubiquitous language for consistent naming in task titles and descriptions. Use state machines to identify workflow tasks. Use aggregate boundaries to scope tasks correctly (one aggregate per task where possible).

**Optional:** Flow catalog (`docs/generalized-requirements/flow-catalog.md`). If present, use flow step sequences and error paths to write more detailed acceptance criteria. Reference specific flow steps when tasks implement multi-step processes.

## Agent Teams Mode (Optional)

Before starting, check if agent teams are enabled by running: `echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

If the value is `1` **and** the service decomposition identifies multiple services, use agent teams to parallelize per-service task generation. If there is only one service, skip this section — a single agent is sufficient.

### Team Topology

Create a team called `generate-jira-tasks` with one teammate per service identified in the service decomposition. For example, if there are 3 services:

| Teammate | Scope | Output |
|---|---|---|
| `tasks-{service-1}` | All requirements assigned to service 1 | `docs/generalized-requirements/jira-tasks.{service-1}.md` |
| `tasks-{service-2}` | All requirements assigned to service 2 | `docs/generalized-requirements/jira-tasks.{service-2}.md` |
| `tasks-{service-3}` | All requirements assigned to service 3 | `docs/generalized-requirements/jira-tasks.{service-3}.md` |

### Coordination

1. **Lead reads all requirements and service decomposition**, then partitions requirements by service ownership.
2. **Spawn one teammate per service** in parallel. Each receives: the service's assigned requirement IDs, the full requirements text for those IDs, the DDD analysis context, the observability decision matrix (Phase 4), and the complete output format template (Phases 1-7).
3. **Teammates generate tasks** for their service and report the completed task document.
4. **Lead handles cross-service concerns**:
   - Merges cross-service dependency tables (Phase 8) across all service documents.
   - Verifies cross-service task references are consistent.
   - Writes the shared observability document (`technical-requirements.observability-and-testing.md`) and checklist (`jira-checklist.observability.md`).
5. **Lead writes final outputs**, ensuring cross-service dependency tables are symmetric.

Each teammate should be spawned as a `general-purpose` subagent with a clear prompt listing: the service's assigned requirement IDs, the full requirements text for those IDs, the DDD analysis context, the observability decision matrix (Phase 4), and the complete output format template (Phases 1-7). If a teammate fails or returns incomplete results, the lead should complete that service's tasks directly rather than re-spawning.

---

## Process

### Phase 1: Task Identification

Read all business and technical requirements. Group related requirements into implementable units:

1. **Infrastructure tasks** come first: project scaffolding, database, message broker, CI/CD.
2. **Foundation tasks**: authentication, error handling, core data models, concurrency control.
3. **Feature tasks**: group by user-facing capability (deposit flow, withdrawal flow, etc.).
4. **Integration tasks**: webhook handling, event publishing, API endpoints.
5. **Admin tasks**: back-office operations, manual overrides.
6. **Finalization tasks**: observability dashboards, notification wiring.

### Phase 2: Dependency Analysis

For each task, identify:
- **Hard dependencies**: tasks that MUST be completed before this one can start.
- **Soft dependencies**: tasks that would be helpful but aren't strictly required (mention in description, not in "Blocked by").

Rules:
- A task should have at most 4-5 hard dependencies. If it has more, you're probably trying to do too much in one task.
- Dependencies should be acyclic (no circular dependencies).
- Transitive dependencies don't need to be listed (if A→B→C, task C only needs to list B, not A).
- But when a task depends on something NOT on its direct predecessor chain (e.g., a Phase 5 task needing a Phase 0 infrastructure component), list it explicitly.

### Phase 3: Implementation Phasing

Assign each task to a phase:
- **Phase 0**: Infrastructure (no business logic)
- **Phase 1**: Foundation (core abstractions, no features)
- **Phase 2**: First feature vertical (data sync, basic queries)
- **Phase 3+**: Feature phases (deposits, instruments, withdrawals, etc.)
- **Final phase**: Admin, notifications, observability finalization

### Phase 4: Observability Integration

For EVERY task, apply the observability decision matrix:

| If the task... | Add to acceptance criteria |
|---|---|
| Adds an API endpoint | RED metrics: request duration histogram + request counter (rate, errors, latency) |
| Adds a background job | Job duration histogram, run counter, records processed counter |
| Adds an external API call | Dependency latency histogram, error counter by type |
| Handles an operation that creates, modifies, or completes a domain entity tracked in the business requirements (any entity referenced by 3+ GBR-* requirements qualifies as "core") | Business metric counters: count + amount by relevant dimensions |
| Adds Kafka consumption | Consumer lag metric, message processing rate |
| Adds Kafka production | Message publish rate, publish errors |
| Changes concurrency/locking | Lock contention metrics |
| Adds significant database operations | Connection pool gauge, query duration histogram by operation type |
| Is on a critical path | K6 load test scenario with specific SLA targets |

If a task matches multiple conditions, apply ALL corresponding criteria (the rows are cumulative, not exclusive). Embed these directly into each task's acceptance criteria — do NOT defer observability to a separate task (except dashboards and alert routing, which go in a finalization task). Use metric names consistent with the project's observability stack. The names below follow Prometheus conventions; adapt to the actual metrics framework (Application Insights, Datadog, etc.) if identified in the technical requirements.

Metric names shown are examples for HTTP endpoints. Prefix all metric names with the service abbreviation in lowercase (e.g., `iam_http_request_duration_seconds` for the IAM service). Apply consistent Prometheus naming conventions (or the project's metrics framework conventions) across all metric types.

**Example:** If a task in the IAM service adds a `POST /api/users` endpoint, its acceptance criteria should include:
`- [ ] Expose histogram metric 'iam_http_request_duration_seconds' with labels method=POST, path=/api/users, status={code} (OBS-001)`
`- [ ] Expose counter metric 'iam_http_requests_total' with same labels (OBS-001)`

### Phase 5: Write Tasks

For each task, produce:

```
### {ID}: {Title}

**Type:** Task | Story  _(Task = technical/infrastructure work; Story = user-facing feature. Do not create Epics — use phase groupings instead.)_
**Priority:** Highest | High | Medium | Low
**Blocked by:** {comma-separated task IDs, or "None"}
**Requirements covered:** {comma-separated requirement IDs}

#### Description

{2-4 paragraphs explaining what this task accomplishes, why it's needed, and key design decisions}

#### Acceptance Criteria

- [ ] {Specific, testable criterion with requirement ID reference}
- [ ] {Metric name and labels if applicable}
- [ ] {K6 scenario ID and SLA if applicable}
- [ ] {Test requirements: unit, integration, or end-to-end}
```

### Phase 6: Dependency Graph

Create a Mermaid `graph TD` dependency graph showing all tasks and their relationships. Use these conventions:
- Each node uses the format `ID[ID: Short Title]`
- Arrows point from dependency to dependent (A --> B means "A must be done before B")
- Group by phase using Mermaid subgraphs with `subgraph Phase N: Label` blocks
- For cross-phase dependencies not on the main chain, add the arrow explicitly

Example for a 6-task service:

````mermaid
graph TD
    subgraph Phase 0: Infrastructure
        SVC-001[SVC-001: Project scaffolding]
        SVC-002[SVC-002: Database setup]
    end
    subgraph Phase 1: Foundation
        SVC-003[SVC-003: Domain models]
    end
    subgraph Phase 2: Core Features
        SVC-004[SVC-004: Repository layer]
        SVC-005[SVC-005: Service layer]
    end
    subgraph Phase 3: API
        SVC-006[SVC-006: API endpoints]
    end

    SVC-001 --> SVC-002
    SVC-001 --> SVC-003
    SVC-002 --> SVC-004
    SVC-003 --> SVC-004
    SVC-003 --> SVC-005
    SVC-004 --> SVC-005
    SVC-005 --> SVC-006
````

### Phase 6.5: Independent Testability Validation

After generating all tasks (Phase 5) and the dependency graph (Phase 6), validate that every task is independently testable:

For each task, ask: **"Can this task's acceptance criteria — especially integration or functional tests — actually pass using only this task's deliverables, without needing work from a downstream task?"**

Common failure patterns to check for:
- **Empty infrastructure**: A task creates database schemas, repositories, or data access modules, but the entities/seed data that populate them are in a separate downstream task. The infrastructure task's integration tests can't run against empty structures.
- **Inert abstractions**: A task creates interfaces/contracts and a registration mechanism, but the first concrete implementation is in a different task. There's nothing to test beyond "it compiles."
- **Wiring without endpoints**: A task sets up middleware, request pipelines, or routing, but the first endpoint that exercises the pipeline is in another task.

**Resolution:** Merge the infrastructure/abstraction task with the first task that populates or exercises it. The merged task should be the smallest unit that produces testable behavior. Update the dependency graph, summary table, and "Blocked by" fields in downstream tasks accordingly.

After merging, re-verify the dependency graph is still acyclic and that no task exceeds the size guideline (1-3 days, or the relaxed target for large requirement sets).

### Phase 7: Coverage Matrix

Create a table mapping EVERY requirement ID to the task(s) that implement it. This includes GBR-* and GTR-* IDs from the generalized requirements as well as OBS-* and K6-* IDs from `technical-requirements.observability-and-testing.md`. Use these columns:

```
| Requirement ID | Covered By | Notes |
|---|---|---|
| GBR-01 | {SVC}-001, {SVC}-003 | |
| GTR-01 | {SVC}-002 | |
| OBS-001 | {SVC}-003 | |
| K6-001 | {SVC}-005 | |
```

The "Covered By" column must list task IDs that include the requirement in their "Requirements covered:" header field. This is the primary validation that nothing was missed.

### Phase 8: Cross-Service Dependencies

If the architecture is single-service, skip this phase and omit the Cross-Service Dependencies section from the output. Otherwise, populate the Cross-Service Dependencies table in the output template.

## Output Format

Write one file per service: `docs/generalized-requirements/jira-tasks.{service-name}.md` (use the service name from the decomposition document, converted to kebab-case, e.g., `jira-tasks.identity-service.md`). Process boundaries that are not separate services (e.g., init containers, seed data initializers) do not get separate task files — their tasks belong to the parent service's file.

```
# Jira Tasks: {Service Name}

## Table of Contents

(Auto-generated TOC listing all phase headings, Summary Table, and Requirement Coverage Matrix)

## Cross-Service Dependencies

(Omit this section for single-service architectures)

| Task | External Dependency | Required Service | Notes |
|---|---|---|---|

## Implementation Order

(Mermaid dependency graph — see Phase 6)

## Phase 0: Infrastructure

### {SVC}-001: {Title}

(Full task descriptions — see Phase 5 template)

## Phase 1: Foundation

...

## Summary Table

| ID | Title | Phase | Priority | Blocked By | Key Requirements |
|---|---|---|---|---|---|

## Requirement Coverage Matrix

| Requirement ID | Covered By | Notes |
|---|---|---|
```

Also write:

### `docs/generalized-requirements/technical-requirements.observability-and-testing.md`

Use `OBS-{###}` as the ID prefix for observability requirements and `K6-{###}` for load test scenarios (zero-padded 3-digit numbers starting from 001, e.g., OBS-001, K6-001). These are new requirement IDs (like GBR/GTR) defined in this document and referenced from task acceptance criteria. They are validated by `/review-requirements` Check 1.

```
# Observability & Testing Requirements: {Service Name}

## Table of Contents

## Cross-Cutting Standards

### RED Metrics
{Standard RED metrics pattern: request rate, error rate, duration for all API endpoints}

### Structured Logging
{Log format, required fields, correlation ID propagation}

### Distributed Tracing
{Trace context propagation, span naming conventions}

## Observability Requirements

### OBS-001: {Short title}

**Requirement:** {Clear requirement statement}

**Applies to:** {Task IDs or "All API endpoints"}

### OBS-002: {Short title}

...

## Dashboard Requirements

| Dashboard | Purpose | Key Panels |
|-----------|---------|------------|
| Operational | System health | Error rates, latency percentiles, throughput |
| Business Metrics | Domain KPIs | {Domain-specific counters and rates} |

## Alert Definitions

| Tier | Condition | Threshold | Response |
|------|-----------|-----------|----------|

## Load Test Scenarios

### K6-001: {Short title}

**Scenario:** {What the test exercises}
**SLA:** {Target metric, e.g., p99 < 200ms at 100 RPS}
**Endpoints:** {Which endpoints are exercised}

### K6-002: {Short title}

...

## Per-Service Metrics Appendix

| Metric Name | Type | Labels | Defined In | OBS-* Reference |
|-------------|------|--------|------------|-----------------|
```

Also write: `docs/generalized-requirements/jira-checklist.observability.md` with this structure:
```
# Observability Checklist

## Decision Matrix
| If the task... | Add to acceptance criteria |
|---|---|
(Copy the Phase 4 decision matrix from the main command)

## Checklist Template
For each Jira task, copy and evaluate:
- [ ] Does this task add an API endpoint? → Add RED metrics (OBS-{ref})
- [ ] Does this task add a background job? → Add job metrics (OBS-{ref})
- [ ] Does this task call an external API? → Add dependency metrics (OBS-{ref})
- [ ] Does this task handle an operation that creates, modifies, or completes a core domain entity? → Add business metrics (OBS-{ref})
- [ ] Does this task add Kafka consumption? → Add consumer lag and processing rate metrics (OBS-{ref})
- [ ] Does this task add Kafka production? → Add publish rate and error metrics (OBS-{ref})
- [ ] Does this task change concurrency/locking? → Add lock contention metrics (OBS-{ref})
- [ ] Does this task add significant database operations? → Add connection pool gauge and query duration histogram (OBS-{ref})
- [ ] Is this task on a critical path? → Add K6 load test scenario (K6-{ref})

## Worked Example
(Apply the checklist to one representative task from the service, showing which items trigger and what acceptance criteria to add)
```

## Self-Review

After producing the output artifacts, follow the self-review convergence protocol in `commands/self-review-protocol.md` to iteratively refine all artifacts until stable (max 5 passes). This command produces multiple files — use Task tool subagents for verification passes 2+ as described in the protocol's Context Window Management section.

## Important

- Use `{SVC}-{###}` as the task ID pattern (e.g., `IAM-001` for Identity & Access Management). The abbreviation should match the service name from the decomposition document.
- Each task should be completable in 1-3 days by a single developer. If it's bigger, split it.
- Acceptance criteria must be CHECKBOXES, not prose. Each one is pass/fail.
- Every acceptance criteria should reference the requirement ID it satisfies.
- **Language-agnostic tasks**: Task descriptions and acceptance criteria must NOT reference specific programming languages, frameworks, or library APIs. They should describe *what* the system does, not *how* a particular framework implements it. For example: write "Create the data access module with repository interfaces for User and Role entities" instead of "Create the EF Core DbContext with IRepository<User> and IRepository<Role>". Write "Add request authentication middleware that validates JWT tokens" instead of "Add ASP.NET Core middleware using JwtBearerHandler". The developer implementing the task chooses the framework and libraries. If the input requirements still contain framework-specific terms that weren't caught by `/generalize-requirements`, map them to language-agnostic equivalents during task generation — do not propagate them into the tasks.
- **Framework-specific architectural patterns**: Beyond terminology, watch for entire acceptance criteria or task descriptions that encode a framework-specific architectural pattern. For each criterion, apply this test: *"Could a developer implement and test this criterion as-written in Elixir, Go, and Java — not just in the original source language?"* If not, the criterion describes a framework-specific mechanism, not a platform-agnostic requirement. Replace it with the underlying need, or remove it. Common patterns to catch:
  - Manual GC/memory management (runtime-specific; remove or replace with a performance SLA)
  - Framework-specific hosting models (e.g., dual-host with shared cancellation; replace with the capability: "metrics and health endpoints available")
  - Runtime-specific concurrency primitives (e.g., "shared cancellation"; replace with the behavior: "clean shutdown on subsystem failure")
  - Framework-specific configuration layering (e.g., a specific 5-layer load order; replace with: "environment-specific configuration overrides")
  - DI container features (e.g., keyed/named registrations; remove — not all languages use DI containers)
  - Serialization setup as a task (e.g., "configure JSON serialization"; remove if the requirement is simply "responses are JSON")
  (See also Phase 6.5 for the related independent testability validation.)
- The dependency graph must match the "Blocked by" fields in every task header AND the summary table. All three must be consistent.
- Coverage matrix is the source of truth: if a requirement ID doesn't appear, something was missed.
- Observability is embedded, not bolted on. Metrics go in the task that creates the thing being measured.
- If the requirements set is very large (100+ requirements), group related requirements more aggressively to keep total task count manageable (target 15-30 tasks per service). When grouping aggressively, individual tasks may exceed the 1-3 day target; the 15-30 task target takes priority — note the estimated scope in the task description.
- **Next step**: Run `/review-requirements` to validate consistency across all generated documents.
