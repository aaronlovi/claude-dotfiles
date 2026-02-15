---
description: "Perform a Domain-Driven Design analysis of a codebase"
argument-hint: <source-dir>
---

You are a Domain-Driven Design expert performing a comprehensive DDD analysis of a codebase. Your goal is to produce a structured document that captures the domain model, integration patterns, and architectural assessment — serving as a foundation for requirements extraction and service decomposition.

## Input

$ARGUMENTS should be the path to the codebase to analyze (default: current working directory). This command works directly on source code — no prerequisite artifacts are needed. If the target path does not exist or contains no source files, stop and tell the user. Source files are identified by the project files found in Phase 0 (e.g., *.csproj → scan for *.cs files; package.json → scan for *.js/*.ts files; go.mod → scan for *.go files).

## Prerequisites

None — this is the first pipeline stage. It operates directly on source code.

## Agent Teams Mode (Optional)

Before starting, check if agent teams are enabled by running: `echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`

If the value is `1`, use agent teams to parallelize the analysis phases. Otherwise, skip this section and execute all phases sequentially as a single agent.

### Team Topology

Create a team called `ddd-analysis` with 3 teammates. The **lead** executes Phases 0-1 (Structural Discovery + Ubiquitous Language) first, since all other phases depend on the language glossary. Then spawn teammates for the parallelizable phases:

| Teammate | Phases | Rationale |
|---|---|---|
| `context-analyst` | Phase 2 (Bounded Contexts) + Phase 3 (Context Mapping) | Both analyze inter-context relationships |
| `tactical-analyst` | Phase 4 (Tactical Pattern Assessment) | Deep per-entity, per-aggregate analysis — the heaviest phase |
| `state-machine-analyst` | Phase 5 (State Machines) | Independent extraction of every status enum and transition |

### Coordination

1. **Lead completes Phases 0-1** and prepares the Ubiquitous Language section for distribution to teammates.
2. **Spawn all 3 teammates** in parallel. Each receives: the ubiquitous language output, the structural discovery results, and their specific phase instructions.
3. **Teammates report their sections** back to the lead.
4. **Lead synthesizes** all sections, then executes Phase 6 (Architectural Assessment) and Phase 7 (Recommendations) — these require the full picture.
5. **Lead writes the final output** to `docs/ddd-analysis.md`.

Each teammate should be spawned as a `general-purpose` subagent with a clear prompt listing: the relevant file paths, the ubiquitous language glossary, their specific phase instructions (copy from the Process section), and the expected output format. Teammates report their sections back to the lead — they do NOT write to the final output file. If a teammate fails or returns incomplete results, the lead should complete that phase's work directly rather than re-spawning. After synthesizing all sections, the lead should verify cross-section terminology consistency before writing.

---

## Process

### Phase 0: Structural Discovery

Before diving into domain analysis, perform a rapid structural survey:
1. **Project files**: Find build files (*.csproj, package.json, go.mod, etc.) to identify the tech stack.
2. **Database**: Find migration files, schema definitions, stored procedures — these are PRIMARY SOURCES for domain logic.
3. **API contracts**: Find proto files, OpenAPI specs, GraphQL schemas.
4. **Configuration**: Find config files, docker-compose files to understand deployment topology.

This phase is quick — use Glob and Grep only, do not read files yet. The goal is to know WHERE to look.

### Phase 1: Ubiquitous Language Extraction

Read the codebase systematically — start with database schemas/migrations (primary source of truth), then enum definitions, then API contracts, then service/business logic files, then tests. Within each category, read files in dependency order (infer from project references, import statements, or directory hierarchy — e.g., `shared/` or `common/` directories before feature directories; if dependency order is unclear, fall back to alphabetical order within each category). Extract EVERY domain term. For each term, capture:

1. **Enums and constants**: These are the most reliable source of domain vocabulary. Find all enums (transaction types, statuses, wallet types, provider types, etc.) and document every value with its business meaning.
2. **Database schema**: Table names, column names, and comments. Pay special attention to status columns and type columns — they encode state machines and classification hierarchies.
3. **API contracts**: Proto files, GraphQL schemas, REST DTOs. These reveal how the domain is presented externally.
4. **Stored procedures / business logic**: Function names and parameters reveal domain operations.
5. **Test fixtures**: Test names often describe business rules in natural language.

For each term, produce:

| Term | Definition | Code Location |
|------|------------|---------------|
| {Term} | {1-2 sentence definition in business language} | {File or table where this is primarily defined} |

Group terms by subdomain (e.g., Core Domain, Integrations, User Management, Compliance, Operations, etc.).

**Important:**
- Include ALL values of every enum, not just the enum name.
- Document relationships between terms (e.g., "A Withdrawal Request contains one or more Withdrawal Destinations").
- Note any overloaded terms (same word used differently in different contexts).
- Capture domain-specific jargon that wouldn't be obvious to a new developer.

### Phase 2: Bounded Context Identification

Identify the bounded context(s) within the codebase and the external contexts it integrates with:

1. **Core responsibilities**: What does this service OWN? What data is authoritative here?
2. **Excluded responsibilities**: What is explicitly delegated to other services?
3. **Related contexts**: Map all external systems and their relationships.
4. **Context ownership matrix**: For every piece of data, who owns it and who consumes it?

Produce an ASCII diagram showing the bounded contexts and their communication channels.

If the service contains multiple potential subdomains (e.g., bonuses within a financial service), analyze whether they should be separate bounded contexts:
- Arguments for keeping together
- Arguments for separating
- Current state of coupling
- Recommendation

### Phase 3: Context Mapping

For each integration point between this service and external systems, identify the DDD context mapping pattern (Customer-Supplier, Anti-Corruption Layer, Published Language, Conformist, Shared Kernel, Open Host Service, or Separate Ways).

For each integration:
- Identify the pattern
- Show the data flow direction
- Note the sync mechanism (gRPC, Kafka CDC, REST webhooks, etc.)
- Identify the contract owner

### Phase 4: Tactical Pattern Assessment

Evaluate each DDD tactical pattern. For each, assess whether it's present, how well it's implemented, and what's missing.

#### Entities
- What objects have identity that persists over time?
- Are entities rich (contain behavior) or anemic (data-only)?
- How is identity managed (auto-increment, GUID, natural key)?
- List each entity with its identity field, key attributes, and behavioral assessment.

#### Value Objects
- What concepts are defined by their attributes rather than identity?
- Are they explicit types or primitive obsession (decimal for money, string for IDs)?
- List existing value objects and identify missing ones.
- For each missing value object, show what it SHOULD look like (brief code example).

#### Aggregates
- What are the consistency boundaries?
- How are they enforced (advisory locks, optimistic concurrency, application-level locks)?
- What invariants does each aggregate protect?
- Are aggregate boundaries explicit in code or implicit in database operations?
- List each aggregate with: root entity, boundary, lock mechanism, invariants.

#### Repositories
- What repository abstractions exist?
- Are they aligned with aggregate boundaries?
- What persistence technology is used?
- How are connections/transactions managed?
- Are repositories thin wrappers or do they contain logic?

#### Domain Services
- Where does business logic live?
- Is it in application code, stored procedures/database functions, or both?
- For split-logic systems, document the division clearly (e.g., orchestration in application code, domain rules in SQL).
- List key domain operations and where their logic resides.

#### Domain Events
- Are domain events explicitly modeled?
- What events are consumed from external systems?
- What events are published?
- Are there internal "events" stored as audit records?
- Is there an event dispatcher or event sourcing pattern?
- Identify missing events that would improve extensibility.

#### Factories
- Is there a factory pattern for complex object creation?
- Where does object creation happen (code, SQL, mapping)?
- What factories are missing?

### Phase 5: State Machine Documentation

For every entity or concept that has status transitions:

1. **Draw the state machine** as an ASCII diagram showing all states and transitions.
2. **Document valid transitions** in a table: From → To, Trigger, Source file/line.
3. **Identify invariants** at each state.
4. **Note enforcement mechanism** (application code vs stored procedure vs database constraint).

### Phase 6: Architectural Assessment

Identify the overall architectural pattern(s) used:

1. **Name the pattern**: Rich Domain Model, Transaction Script, Table Module, Smart Database, CQRS, Event Sourcing, etc.
2. **Draw the layered architecture** as an ASCII diagram.
3. **Assess DDD alignment** for each principle:

| Principle | Alignment (High/Medium/Low/None) | Evidence |
|-----------|----------------------------------|----------|

4. **Document trade-offs**: What was gained and what was lost with this architectural choice?
5. **When this architecture is appropriate** vs **when it becomes problematic**.

### Phase 7: Recommendations

Provide 4-8 specific, actionable recommendations. For each:
- What to do
- Why (what problem it solves)
- Brief code example showing the target state
- Whether it's a documentation-only change or requires code modification

Prioritize recommendations that improve understanding and maintainability without requiring large rewrites.

## Output Format

Create the `docs/` directory if it doesn't exist, then write the output to `docs/ddd-analysis.md` with this structure:

```
# Domain-Driven Design Analysis: {Service Name}

## Table of Contents

## Executive Summary

### Key Findings
(Assessment table: Aspect | Alignment | Notes)

### Architectural Pattern
(1-2 paragraphs identifying the primary pattern)

## Ubiquitous Language

### {Subdomain 1} Terms
| Term | Definition | Code Location |
|------|------------|---------------|

### {Subdomain 2} Terms
...

## Bounded Contexts

### The {Service} Context
(Core responsibilities, excluded responsibilities)

### Related Bounded Contexts
(ASCII diagram, ownership matrix)

### Potential Subdomain Separations
(Analysis of whether internal subdomains should be separate)

## Context Mapping

### {Pattern 1}: {Integration Name}
(Description, data flow, implementation)

### Context Map Summary
| Integration | Pattern | Direction | Mechanism |
|-------------|---------|-----------|-----------|

## Tactical Patterns

### Entities
(Per-entity assessment)

### Value Objects
(Existing + missing)

### Aggregates
(Per-aggregate: root, boundary, lock, invariants)

### Repositories
(Assessment of abstractions and implementations)

### Domain Services
(Split analysis: where logic lives)

### Domain Events
(Inbound, outbound, internal, missing)

### Factories
(Present or absent, what's needed)

## State Machines

### {State Machine 1}
(ASCII diagram + transition table)

## Architectural Assessment

### Overall DDD Alignment
(Principle alignment table)

### Architectural Style
(Layered diagram, trade-offs)

## Recommendations

### 1. {Recommendation Title}
(What, why, code example)
```

## Important

- This analysis must be THOROUGH. Read every enum, every stored procedure name, every proto file. The ubiquitous language section is the foundation — if you miss terms here, downstream analysis suffers.
- Be HONEST about DDD alignment. If the codebase uses Transaction Script and anemic entities, say so — it's often a valid architectural choice, especially for systems requiring strong transactional consistency.
- Don't just identify what's missing — explain WHY the current approach was likely chosen (trade-offs) and WHETHER the missing pattern would actually improve things.
- State machines are critical for any system with workflows. Document EVERY status enum and its valid transitions.
- Include code locations (file:line or table name) for everything. This document should be navigable by a developer who wants to verify your analysis.
- If the codebase has business logic in stored procedures or database functions, those are PRIMARY SOURCES. Read them with the same rigor as application code.
- The recommendations should be pragmatic. Don't recommend rewriting a working system to use rich domain models unless there's a compelling reason.
- **Next step**: Run `/analyze-codebase {source-dir}` to produce a reading order guide for the codebase.
