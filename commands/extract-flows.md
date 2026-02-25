---
description: "Extract and catalog major system flows with inputs, outputs, happy paths, and error paths"
argument-hint: <requirements-dir>
---

You are a senior architect extracting and cataloging the major system flows from project-specific requirements. Your goal is to produce a **flow catalog** — a human-readable, tabular document that describes how actors interact with the system, what data flows in and out, what the happy paths look like step by step, and what can go wrong.

## Input

$ARGUMENTS should be the path to the project-specific requirements directory (e.g., `docs/requirements/`). If empty, look for `docs/requirements/`. If the specified path is a file rather than a directory, use its parent directory. If the target path does not exist, stop and tell the user.

## Prerequisites

**Required:** Business requirements (`business-requirements.md`) and technical requirements (`technical-requirements.md`) in the input directory. If either is missing, stop and tell the user to run `/extract-requirements` first.

**Optional:** DDD analysis (`docs/ddd-analysis.md`). If present:
- Use the state machines section to identify flows with explicit state transitions and their valid/invalid paths.
- Use the ubiquitous language glossary to ensure consistent terminology in flow descriptions.
- Use the context mapping section to identify cross-system integration flows.

## Process

### Phase 1: Flow Identification

Read all requirements and the DDD analysis (if present). Identify distinct flows by scanning for:

| Signal | Where to Look | Example |
|--------|---------------|---------|
| Sequential/procedural requirements | Business requirements describing multi-step processes | "Build authorization URL → redirect → receive callback → exchange code → issue session" |
| State machine transitions | DDD analysis state machine section | User account: CREATED → ACTIVE → LOCKED OUT |
| API endpoint operations | Technical requirements describing request/response contracts | "POST /api/users creates a new user and returns the created entity" |
| Integration patterns | DDD analysis context mapping, technical requirements | "CDC event consumed from external system triggers local state update" |
| Error handling requirements | Technical requirements with error codes, rejection conditions | "Reject with ACCOUNT_LOCKED if failed attempts exceed threshold" |
| Background/scheduled processes | Requirements describing periodic or event-driven jobs | "Seed data merged on startup from configuration files" |

Group identified flows into categories derived from the domain areas in the business requirements (e.g., Authentication, SSO Federation, User Management, RBAC). Not every requirement maps to a distinct flow — many requirements describe constraints or rules within a larger flow.

**Scoping guidance:** Focus on flows that have non-trivial sequences (3+ steps) or meaningful error paths. Simple CRUD operations (create entity, list entities) should be consolidated into a single "Entity Management" flow per domain area unless they have notable error paths or multi-step logic. Target 10-20 flows for a typical service. Adjust based on actual domain complexity — a focused service may have fewer, a complex one more.

### Phase 2: Flow Decomposition

For each identified flow, extract the following using tabular format:

| Element | What to Capture |
|---------|-----------------|
| **Trigger** | What initiates the flow (user action, API call, system event, scheduled job) |
| **Actors** | Who or what participates (end user, admin, external system, background process) |
| **Inputs** | Data entering the flow — name, type/format, source, whether required, validation rules |
| **Outputs** | Data produced by the flow — name, type/format, destination, under what conditions |
| **Happy path** | Numbered steps: who does what, the system's response, what data changes |
| **Error paths** | Where the happy path can diverge: the condition, the system's response, error code, and how to recover |
| **Requirements covered** | BR-*/TR-* IDs that this flow implements or partially implements |

When decomposing error paths:
- Include only error conditions explicitly described in requirements or DDD analysis state machines. Do not invent hypothetical errors.
- Group related error conditions (e.g., all validation failures at the same step) into a single error path row with the conditions listed.
- For state machines, every invalid transition is an error path.

### Phase 3: Cross-Flow Analysis

After decomposing all flows, analyze their interactions:

| Analysis | Purpose |
|----------|---------|
| **Flow interaction matrix** | Which flows trigger other flows? (e.g., "SSO Login" triggers "User Auto-Creation" under certain conditions) |
| **Shared error patterns** | Common error handling that appears across multiple flows (e.g., authorization check, input validation, concurrency conflict) |
| **Cross-domain flows** | Flows that span multiple domain areas — these are candidates for integration points in service decomposition |
| **Requirement coverage** | Verify every BR-* requirement appears in at least one flow's Requirements list. Place each TR-* requirement in either "Covered Requirements" (if it maps to a specific flow) or "System-Wide Constraints" (if it applies globally). Flag any BR-* requirement not covered by any flow in the "Uncovered Requirements" subsection. |

### Phase 4: Write Output

Assemble the flow catalog using the output format below.

## Output Format

Write to `docs/requirements/flow-catalog.md`:

```
# Flow Catalog: {Service Name}

## Table of Contents

- [Flow Summary](#flow-summary)
- [{Category 1}](#category-1)
  - [Flow: {Flow Name}](#flow-flow-name)
  - ...
- [{Category 2}](#category-2)
  - ...
- [Flow Interaction Matrix](#flow-interaction-matrix)
- [Shared Error Patterns](#shared-error-patterns)
- [Requirement Coverage](#requirement-coverage)

## Flow Summary

| # | Flow | Category | Trigger | Actors | Key Requirements |
|---|------|----------|---------|--------|------------------|
| 1 | {Flow Name} | {Category} | {What starts it} | {Who's involved} | BR-..., TR-... |
| 2 | ... | ... | ... | ... | ... |

## {Category 1}

### Flow: {Flow Name}

#### Overview

| Field | Value |
|-------|-------|
| Trigger | {What initiates this flow} |
| Actors | {Who participates} |
| Preconditions | {What must be true before this flow can start} |
| Postconditions | {What is true after successful completion} |
| Requirements | BR-..., TR-... |

#### Inputs

| Input | Type / Format | Source | Required | Validation |
|-------|---------------|--------|----------|------------|
| {name} | {type} | {where it comes from} | Yes/No | {rules} |

#### Outputs

| Output | Type / Format | Destination | Condition |
|--------|---------------|-------------|-----------|
| {name} | {type} | {where it goes} | {when produced} |

#### Happy Path

| Step | Actor | Action | System Response | Data Changed |
|------|-------|--------|-----------------|--------------|
| 1 | {who} | {does what} | {system does what} | {what state changes} |
| 2 | ... | ... | ... | ... |

#### Error Paths

| Diverges At | Condition | System Response | Error Code | Recovery |
|-------------|-----------|-----------------|------------|----------|
| Step {N} | {what goes wrong} | {what system does} | {code/message} | {how to recover} |

---

### Flow: {Next Flow Name}

...

## {Category 2}

...

## Flow Interaction Matrix

| Flow | Triggers | Triggered By | Notes |
|------|----------|--------------|-------|
| {Flow A} | {Flow B}, {Flow C} | {Flow D} | {conditions} |

## Shared Error Patterns

| Pattern | Applies To | Behavior | Requirements |
|---------|------------|----------|--------------|
| {e.g., Authorization Check} | {list of flows} | {what happens} | TR-... |

## Requirement Coverage

### Covered Requirements

| Requirement | Covered By Flow(s) |
|-------------|---------------------|
| BR-XXX-NN | {Flow Name} |

### System-Wide Constraints (Not Flow-Specific)

| Requirement | Description |
|-------------|-------------|
| TR-XXX-NN | {constraint that applies globally, not to a specific flow} |

### Uncovered Requirements

| Requirement | Notes |
|-------------|-------|
| {any orphaned requirements} | {why not covered} |
```

## Self-Review

After producing the output artifact, follow the self-review convergence protocol in `~/.claude/commands/self-review-protocol.md` to iteratively refine the artifact until stable (max 5 passes).

## Important

- This document is for **human readers**, not Claude. Write clear, concise prose in flow descriptions. Avoid jargon that requires reading the requirements to understand.
- Use **tabular format throughout**. Do not use bullet-point lists for flow steps, inputs, outputs, or error paths.
- The **Table of Contents** must appear at the top and link to all major sections.
- Focus on **major flows** (see scoping guidance in Phase 1). Consolidate simple CRUD into summary flows. The goal is a navigable overview, not an exhaustive specification.
- **Error paths must come from requirements**, not imagination. Only document error conditions explicitly stated in business requirements, technical requirements, or DDD analysis state machines.
- Use **project-specific terminology** (BR-*/TR-* IDs, domain-specific terms as they appear in the requirements). The flow catalog will be generalized in a separate stage (`/generalize-flows`).
- The **Requirement Coverage** section is critical — it validates that the flow catalog accounts for all requirements. Orphaned requirements signal missing flows or overlooked system behaviors. TR-* requirements must appear in either "Covered Requirements" or "System-Wide Constraints" — never in "Uncovered Requirements". Only BR-* requirements may appear in "Uncovered Requirements" (when no flow covers them).
- Pre/postconditions in the Overview table should be concrete and testable (e.g., "User exists and is in ACTIVE state"), not vague (e.g., "System is ready").
- This command produces a single synthesized output and does not support Agent Teams parallelization.
- **Next step**: Run `/generalize-requirements docs/requirements/` to produce platform-agnostic requirements (Stage 4). See `/pipeline` for the full sequence of subsequent stages.
