---
description: "Extract business and technical requirements from a codebase"
argument-hint: <reading-order-or-source-path>
---

You are a senior business analyst and software architect extracting requirements from an existing codebase. You will read through the code and produce two structured documents: business requirements and technical requirements.

## Input

$ARGUMENTS should be one of:
- A path to a reading order guide (e.g., `docs/codebase-analysis/reading-order.md`)
- A path to a source directory to analyze (a minimal structural survey will be performed to establish a reading order; for best results, run `/analyze-codebase` first)
- Empty (will look for an existing reading order guide in `docs/codebase-analysis/`; if none exists, falls back to analyzing the current working directory as a source directory)

If the specified path does not exist, stop and tell the user. If a directory is provided, check for `reading-order.md` inside it before treating it as a source directory. If a file is provided but doesn't appear to be a reading order guide (no "Reading Order" or "Group" headings), treat its **parent directory** as a source directory path instead.

## Prerequisites

**Optional:** DDD analysis (`docs/ddd-analysis.md`). If present, use the ubiquitous language as the basis for naming requirements. Use bounded context boundaries to organize requirement domains. Use state machines to identify workflow requirements. Reference aggregate invariants as business rules. Every business requirement should trace to at least one ubiquitous language term, and the domain groupings should align with the bounded contexts identified there.

**Optional:** Reading order (`docs/codebase-analysis/reading-order.md`). If present, follow it instead of doing ad-hoc file discovery.

## Agent Teams Mode (Optional)

Before starting, check if agent teams are enabled by running: `echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

If the value is `1`, use agent teams to parallelize the reading and extraction phases. Otherwise, skip this section and execute all phases sequentially as a single agent.

### Team Topology

Create a team called `extract-requirements` with 2 teammates:

| Teammate | Scope | Rationale |
|---|---|---|
| `business-extractor` | Read codebase and extract **business rules**: conditions, validations, workflows, domain logic. Produce draft business requirements grouped by domain area. | Business and technical extraction are different lenses on the same code |
| `technical-extractor` | Read codebase and extract **technical patterns**: concurrency, caching, security, error handling, data integrity, API contracts, observability. Produce draft technical requirements grouped by concern. | Can read the same files in parallel with a different focus |

### Coordination

1. **Lead reads prerequisite artifacts** (DDD analysis, reading order) and shares paths with teammates.
2. **Spawn both teammates** in parallel. Each receives: the reading order (or codebase path), their specific extraction focus, the corresponding output format template (business requirements format for business-extractor, technical requirements format for technical-extractor), and the DDD analysis context (if present).
3. **Teammates report draft requirements** back to the lead.
4. **Lead executes Phase 4** (Cross-Reference): merges, deduplicates, ensures every business requirement maps to at least one technical requirement, assigns phases, and resolves ID numbering.
5. **Lead writes final output** to `docs/requirements/business-requirements.md` and `docs/requirements/technical-requirements.md`.

Each teammate should be spawned as a `general-purpose` subagent with a clear prompt listing: the reading order (or codebase path), their specific extraction focus, the corresponding output format template (business requirements format for business-extractor, technical requirements format for technical-extractor), and the DDD analysis context (if present). Teammates only read files and report findings — the lead handles all output writing. If a teammate fails or returns incomplete results, the lead should complete that phase's work directly rather than re-spawning.

---

## Process

### Phase 1: Read the Codebase

Follow the reading order guide (or, if analyzing a source directory directly, perform a quick structural survey per Phase 0-1 of `/analyze-codebase` to establish a reading order). For each file:
1. Read the file thoroughly.
2. Extract **business rules** — conditions, validations, workflows, domain logic.
3. Extract **technical patterns** — concurrency, caching, security, error handling, data integrity.
4. Note **implicit requirements** — things the code enforces that aren't documented anywhere.

### Phase 2: Organize Business Requirements

Group requirements by domain area. The categories below are examples from a financial domain — derive category names from the actual domain of the codebase being analyzed. If a DDD analysis exists, use its bounded contexts or subdomain groupings as the starting point:
- **Core entities** (e.g., users, accounts, wallets, orders)
- **Transaction flows** (e.g., deposits, withdrawals, purchases)
- **User restrictions and validations**
- **External integrations**
- **Background processing**
- **Admin operations**
- **Notifications**

For each requirement:
- Assign a unique ID: `BR-{DOMAIN}-{##}` (e.g., `BR-USER-01`, `BR-AUTH-03`)
- Write a clear, testable requirement statement
- Note the source file(s) where this requirement is implemented
- Identify dependencies on other requirements or external systems
- Assign a preliminary implementation phase (which requirements must exist before this one). Note: the `/generate-jira-tasks` command will finalize phases based on full dependency analysis.

### Phase 3: Organize Technical Requirements

Group by technical concern:
- **Infrastructure** (database, message broker, CI/CD, secrets)
- **Authentication & Authorization** (JWT, API keys, privileges)
- **Error Handling** (codes, sanitization, mapping)
- **Data Integrity** (idempotency, audit trails, immutability)
- **Concurrency** (locking, serialization, deadlock prevention)
- **Performance** (batching, caching, streaming)
- **API Contracts** (encoding, sign conventions, pagination)
- **Observability** (metrics, logging, tracing)
- **Configuration** (toggles, intervals, feature flags)
- **Background Processing** (schedulers, recovery, singletons)
- **Message Queue** (consumers, producers, topics)

For each requirement:
- Assign a unique ID: `TR-{DOMAIN}-{##}` (e.g., `TR-INFRA-01`, `TR-CONC-03`)
- Write a clear requirement statement
- Note the source file(s)
- Identify dependencies

### Phase 4: Cross-Reference

- Every business requirement should map to at least one technical requirement or be self-contained.
- Identify gaps: code that exists but has no clear business justification.
- Identify implicit requirements: business rules enforced only by database constraints or stored procedures.

## Output Format

Create `docs/requirements/` if it doesn't exist, then write two files:

### `docs/requirements/business-requirements.md`
```
# Business Requirements: {Service Name}

## External Dependencies

| Dependency | Required For | Mechanism |
|---|---|---|

## Implementation Phases

| Phase | Name | Prerequisites |
|---|---|---|

## {Domain Area 1}

### BR-XXX-01: {Short title}

**Requirement:** {Clear, testable requirement statement}

**Source:** {File path(s) where this is implemented}
**Phase:** {N}
**Dependencies:** {Other BR/TR IDs, or "None"}

### BR-XXX-02: {Short title}

...

## {Domain Area 2}

...
```

### `docs/requirements/technical-requirements.md`
```
# Technical Requirements: {Service Name}

## Implementation Phases

| Phase | Name | Key Technical Concerns |
|---|---|---|

## {Technical Area 1}

### TR-XXX-01: {Short title}

**Requirement:** {Clear requirement statement}

**Source:** {File path(s)}
**Phase:** {N}
**Dependencies:** {Other TR/BR IDs, or "None"}

### TR-XXX-02: {Short title}

...

## {Technical Area 2}

...
```

## Important

- Requirements describe WHAT and WHY, not HOW. Implementation details go in technical requirements only when they constrain the solution space.
- Be precise: "configurable timeout" not "timeout"; "reject with INSUFFICIENT_BALANCE" not "check balance".
- Each requirement should be independently testable. If a requirement contains the word "and" connecting two distinct behaviors, split it into two requirements.
- Include edge cases you find in the code — they represent hard-won lessons.
- If business logic lives in stored procedures or database functions, those are PRIMARY SOURCES. Read them carefully.
- Flag any contradictions between code behavior and comments/documentation.
- **Next step**: Run `/extract-flows docs/requirements/` to catalog major system flows (optional but recommended), then `/generalize-requirements docs/requirements/` to produce platform-agnostic requirements for downstream pipeline stages.
