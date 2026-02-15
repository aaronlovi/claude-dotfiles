---
description: "Identify service boundaries and integration points from requirements"
argument-hint: <generalized-requirements-dir>
---

You are a domain-driven design expert analyzing requirements to identify optimal service boundaries. Your goal is to recommend how to split (or validate the split of) a system into independently deployable services.

## Input

$ARGUMENTS should be the path to generalized requirements (e.g., `docs/generalized-requirements/`). If empty, look for `docs/generalized-requirements/`. If the target path does not exist, stop and tell the user.

## Prerequisites

**Required:** Generalized business and technical requirements in the input directory. If missing, stop and tell the user to run `/generalize-requirements` first.

**Optional:** Flow catalog (`docs/generalized-requirements/flow-catalog.md`). If present, use the flow interaction matrix and cross-domain flows to inform service boundary decisions — flows that span multiple domain areas suggest integration points between services.

**Optional:** DDD analysis. Prefer the generalized version (`docs/generalized-requirements/ddd-analysis.md`) if it exists; fall back to the original (`docs/ddd-analysis.md`). If present:
- Use the bounded context section as the starting point — it already identifies context boundaries and their rationale.
- Use the context mapping section to establish integration patterns between services.
- Use the aggregate boundaries to validate that proposed service splits don't break transactional consistency.
- Use the "Potential Subdomain Separations" analysis if it exists.
- If your decomposition differs from the DDD analysis's bounded context recommendations, document the divergence and rationale in the output — do NOT modify the DDD analysis document.
- If using the original (non-generalized) DDD analysis, be aware it uses pre-generalization terminology. Use the terminology mapping from the generalized requirements' traceability appendices when cross-referencing.

## Process

### Phase 1: Identify Bounded Contexts

Read all requirements and identify natural groupings. If a DDD analysis is available (see Prerequisites), use its bounded context section as the starting point rather than identifying groupings from scratch — validate existing context boundaries against the requirements.

1. **Data ownership**: Which requirements operate on the same core data? Group them.
2. **Transactional boundaries**: Which operations must be atomic together? They belong in the same service.
3. **Change frequency**: Requirements that change together should be in the same service.
4. **Team ownership**: If different teams own different areas, those are natural boundaries.
5. **Scaling profiles**: Requirements with different load patterns (high-frequency reads vs batch processing) may warrant separation.

### Phase 2: Define Service Candidates

For each candidate service:
- **Name and purpose** (1-2 sentences)
- **Abbreviation** (3-4 uppercase character ID prefix for use in `/generate-jira-tasks`, e.g., `IAM` for Identity & Access Management)
- **Owned data** (which tables/entities this service owns exclusively)
- **Business requirements** (list of GBR-* requirement IDs)
- **Technical requirements** (list of GTR-* requirement IDs)
- **Why this is a separate service** (the DDD/architectural rationale)

### Phase 3: Map Integration Points

For each pair of services that communicate:

| From | To | Type | Mechanism | Data | Notes |
|---|---|---|---|---|---|

Classify the Type column for each integration:
- **Command** (one service tells another to do something): gRPC/REST call
- **Query** (one service asks another for data): gRPC/REST call
- **Event** (one service notifies others of something that happened): message queue
- **Data sync** (one service mirrors data from another): CDC/Kafka

### Phase 4: Validate Boundaries

Check for anti-patterns:
1. **Circular dependencies**: Service A depends on B depends on A. Resolve by extracting shared logic or inverting a dependency.
2. **Chatty interfaces**: If two services need to call each other frequently for every operation, they should probably be one service.
3. **Distributed transactions**: If an operation requires atomic changes across two services, reconsider the boundary.
4. **Shared database**: Two services should NOT share a database. If they need the same data, use events/sync.
5. **Anemic services**: A service with very few requirements might not justify the operational overhead. Consider merging. (Skip this check if the analysis concluded a single-service architecture is appropriate.)

### Phase 5: Implementation Order

Determine which service should be built first:
- Services with no upstream dependencies come first.
- Services that provide data to others come before their consumers.
- The core domain service (the one that other services depend on) usually comes first.

## Output Format

Write to `docs/generalized-requirements/service-decomposition.md`:

```
# Service Decomposition

## Service Map

(ASCII diagram showing services and their communication)

## Services

### {Service 1 Name}

- **Purpose**: ...
- **Abbreviation**: ... (3-4 char ID prefix for Jira tasks, e.g., IAM)
- **Owned data**: ...
- **Business requirements**: GBR-...
- **Technical requirements**: GTR-...
- **Why separate**: ...

### {Service 2 Name}

...

## Integration Points

| From | To | Type | Mechanism | Data | Notes |
|---|---|---|---|---|---|

## Implementation Order

1. {Service} — rationale
2. {Service} — rationale
...

## Anti-Pattern Check

Evaluate each pattern. Convention: `[x]` = confirmed absent (clean), `[ ] CONCERN: {description}` = potential issue found.

- [x] No circular dependencies
- [x] No chatty interfaces
- [x] No distributed transactions required
- [x] No shared databases
- [x] No anemic services
```

## Important

- Fewer services is usually better. Don't split for the sake of splitting.
- The "right" number of services depends on team size, deployment capabilities, and operational maturity. Process boundaries that are not separate services (e.g., init containers, seed data initializers) do not get separate service entries — they belong to the parent service with a note about the process boundary.
- If a service would only have 3-5 requirements, it's probably not worth the operational overhead unless it has a fundamentally different scaling profile.
- Events are preferred over synchronous calls for cross-service communication where eventual consistency is acceptable.
- If the analysis concludes the system should remain a single service, document this decision with rationale (e.g., transactional consistency, tight coupling, team size). Still produce the service-decomposition.md file with a single service entry — downstream commands (`/generate-jira-tasks`) need this document to exist.
- This command produces a single synthesized output and does not support Agent Teams parallelization.
- **Next step**: Run `/generate-jira-tasks` to create implementation-ordered tasks from the requirements and service decomposition.
