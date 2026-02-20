---
description: "Generalize domain-specific requirements into a platform-agnostic form"
argument-hint: <requirements-dir>
---

You are a senior architect generalizing requirements from a specific domain implementation into a reusable, platform-agnostic form. The goal is to produce requirements that could be implemented for ANY platform in the same industry vertical (e.g., any gaming platform, any fintech platform), not just the original product.

## Input

$ARGUMENTS should be the path to the requirements documents to generalize (e.g., `docs/requirements/`). If empty, look for requirements in `docs/requirements/`. If the target path does not exist, stop and tell the user.

## Prerequisites

**Required:** Business requirements (`business-requirements.md`) and technical requirements (`technical-requirements.md`) in the input directory. If either is missing, stop and tell the user to run `/extract-requirements` first.

**Optional:** DDD analysis (`docs/ddd-analysis.md`). This command always uses the ORIGINAL DDD analysis (not the generalized version), because the terminology mapping is built by comparing original domain terms against generalized equivalents. If present:
- Use the ubiquitous language glossary to build the terminology mapping table — each domain-specific term should have a generalized equivalent or be marked as excluded.
- Use the bounded context analysis to identify which subdomains should be extracted to separate services.
- Use the context mapping patterns to preserve integration architecture during generalization.
- Do NOT modify the original DDD analysis document — it captures the original domain model. The terminology mapping table in THIS command's output serves as the bridge between original and generalized terms.

A separate command (`/generalize-ddd-analysis`) can be run after this one to produce a generalized version of the DDD analysis using the terminology mapping you create here.

## Process

### Phase 1: Identify Domain-Specific Elements

Read through all requirement documents and categorize each requirement:

1. **Core/Universal**: Requirements that apply to ANY platform in this vertical. These survive generalization unchanged (except terminology updates).
   - Examples: user management, authentication flows, RBAC enforcement, audit trails.

2. **Configurable/Parameterized**: Requirements that are specific in the original but can be made configurable.
   - Example: A domain-specific action → a configurable action type (same concept, different domain term).
   - Example: A hardcoded threshold → a configurable limit.

3. **Domain-Specific (Exclude)**: Requirements that are deeply tied to the original domain and don't generalize.
   - These should be listed as EXCLUDED, not silently dropped.
   - Example: product-specific business logic, vendor-specific integration details.

4. **Extractable to Separate Service**: Requirements that represent a distinct bounded context and should be a separate service.
   - Example: Promotions/bonuses, domain-specific processing, auxiliary workflows.

### Phase 2: Build the Terminology Map

Create a terminology mapping table covering ALL of these categories:
- Entity/concept name changes (e.g., "poker table" → "activity session")
- Enum value changes (e.g., status values, type values)
- Privilege/permission name changes
- Function/procedure name changes (stored procedures, API operation names)
- Operator/license/vendor name removals (replace with "configurable" equivalents)
- **Implementation/framework term changes**: Identify ALL language-specific, framework-specific, or library-specific terms and map them to language-agnostic equivalents. The test: someone implementing in Go, Java, TypeScript, or Rust should be able to read the generalized requirements without encountering concepts tied to a specific language or framework. Common mappings include:
  - Web server/host names (e.g., "Kestrel host", "Express server", "Gin router") → "HTTP server" or "listener endpoint"
  - ORM/data access concepts (e.g., "EF Core context", "DbContext", "Hibernate session") → "data access module"
  - Request pipeline concepts (e.g., "middleware pipeline", "filter chain") → "request processing pipeline"
  - Background execution (e.g., "hosted service", "goroutine", "Worker Service") → "background service" or "background task"
  - Interface naming conventions (e.g., "IRepository", "IUnitOfWork") → "repository pattern", "unit of work pattern" (name the pattern, not the interface)
  - DI/IoC concepts (e.g., "DI container with named registrations", "service provider") → remove or replace with "dependency injection" only if the concept itself is relevant
  - Framework-specific configuration patterns (e.g., "Options pattern", "appsettings.json", "application.yml") → "application configuration" or remove if it's a pure implementation detail
  - Framework names (e.g., "ASP.NET Core", "Spring Boot", "NestJS", "Rails") → remove; describe the capability instead (e.g., "ASP.NET Core Web API" → "REST API service")
  - Language-specific type names (e.g., "Task\<T\>", "CompletableFuture", "Promise") → "async operation" or describe the behavior

  **Judgment call — generalize vs. remove:** If a framework term describes a *capability* the system needs (e.g., "background service" for scheduled work), generalize it. If it describes *how* a specific framework delivers that capability (e.g., "Options pattern" for config binding), remove it — the requirement should state what configuration is needed, not how the framework loads it.

| Original Term | Generalized Term | Notes |
|---|---|---|
| (domain-specific term) | (platform-agnostic equivalent) | (category: entity/enum/privilege/function/vendor) |
| (domain-specific term) | (excluded — domain-specific) | ... |

Downstream commands (`/generalize-ddd-analysis`, `/generalize-flows`) consume this table to transform all remaining documents. Every domain-specific term that appears in the DDD analysis, flow catalog, or requirements must have a mapping entry here.

**Conflict resolution:** If two original terms would map to the same generalized term, disambiguate by appending the domain area (e.g., `session` in auth vs. `session` in activity becomes `auth-session` and `activity-session`). If the BR and TR traceability appendices disagree on a term mapping, the BR mapping is authoritative for entity/concept names and the TR mapping is authoritative for technical/infrastructure names.

Apply these substitutions consistently across ALL requirements.

### Phase 3: Structural Changes

Beyond terminology, look for structural generalizations. The examples below are illustrative — only apply the ones relevant to this codebase. If none apply, skip this phase and include in the output document: "No structural generalizations needed beyond terminology mapping."

1. **Hardcoded values → Configuration**: Replace any hardcoded thresholds, timeouts, or limits with "configurable" language.
2. **Specific providers → Provider pattern**: Replace references to specific vendor integrations with a generic provider registry pattern.
3. **Fixed workflows → Configurable state machines**: If the original has a fixed workflow, consider whether it should be configurable.
4. **Single-variant assumptions → Multi-variant**: If the original assumes a single currency, locale, or tenant, generalize to configurable variants.

### Phase 4: Consolidation and Renumbering

- Merge requirements that were split unnecessarily in the original.
- Split requirements that are doing too much.
- Renumber using the generalized ID prefix convention: `GBR-{NN}` for business requirements, `GTR-{NN}` for technical requirements (2-digit zero-padded, e.g., GBR-01, GTR-12; use 3-digit if 100+ requirements; sequential within each document). This distinguishes generalized IDs from the originals (`BR-*`, `TR-*`). Group requirements by domain area using section headings, not ID infixes.
- Preserve phase assignments from the original requirements. If merging or splitting requirements changes the appropriate phase, adjust accordingly. Phase assignments are validated by `/review-requirements` Check 4.
- Maintain a traceability section mapping old IDs to new IDs.

### Phase 5: Service Extraction Tagging

For requirements that belong to a different bounded context:
- Tag them with a suggested service assignment in the "Extracted to separate services" section.
- Do NOT create separate per-service requirement documents here — that is the responsibility of the `/decompose-services` command.
- Ensure the core service's requirements reference the extracted domains as external dependencies.

## Output Format

Create `docs/generalized-requirements/` if it doesn't exist. Write generalized versions of the requirement documents:

- `docs/generalized-requirements/business-requirements.md`
- `docs/generalized-requirements/technical-requirements.md`

Use this document structure for each file:

### `docs/generalized-requirements/business-requirements.md`
```
# Business Requirements: {Generalized Service Name}

## Table of Contents

## External Dependencies

| Dependency | Required For | Mechanism |
|---|---|---|

## Implementation Phases

| Phase | Name | Prerequisites |
|---|---|---|

## {Domain Area 1}

### GBR-NN: {Short title}

**Requirement:** {Clear, testable requirement statement}

**Phase:** {N}
**Dependencies:** {Other GBR/GTR IDs, or "None"}

...

## {Domain Area 2}

...

## Excluded from This Document

| Original ID | Title | Reason |
|---|---|---|

## Extracted to Separate Services

| Original ID | Title | Suggested Service |
|---|---|---|

## Traceability from Original Requirements

### ID Mapping

| Original ID | Generalized ID | Notes |
|---|---|---|
| BR-XXX-NN | GBR-NN | |

### Terminology Changes — Domain Terms

| Original Term | Generalized Term | Notes |
|---|---|---|

### Terminology Changes — Implementation/Framework Terms

| Original Term | Generalized Term | Notes |
|---|---|---|
```

### `docs/generalized-requirements/technical-requirements.md`
```
# Technical Requirements: {Generalized Service Name}

## Table of Contents

## Implementation Phases

| Phase | Name | Key Technical Concerns |
|---|---|---|

## {Technical Area 1}

### GTR-NN: {Short title}

**Requirement:** {Clear requirement statement}

**Phase:** {N}
**Dependencies:** {Other GTR/GBR IDs, or "None"}

### GTR-NN: {Short title}

...

## {Technical Area 2}

...

## Excluded from This Document

| Original ID | Title | Reason |
|---|---|---|

## Extracted to Separate Services

| Original ID | Title | Suggested Service |
|---|---|---|

## Traceability from Original Requirements

### ID Mapping

| Original ID | Generalized ID | Notes |
|---|---|---|
| TR-XXX-NN | GTR-NN | |

### Terminology Changes — Domain Terms

| Original Term | Generalized Term | Notes |
|---|---|---|

### Terminology Changes — Implementation/Framework Terms

| Original Term | Generalized Term | Notes |
|---|---|---|
```

## Important

- The generalized requirements must be IMPLEMENTABLE. Don't over-abstract to the point of being meaningless.
- Keep the same level of detail as the originals. Generalization means changing SCOPE, not reducing DEPTH.
- When in doubt about whether something is domain-specific, make it configurable rather than excluding it.
- For requirements with domain-specific VALUES but universal CONCEPTS, keep the requirement and mark specific values as "configurable (default: {original value})".
- Preserve edge cases and hard-won business rules — these are the most valuable parts of the requirements.
- This command produces a single synthesized output and does not support Agent Teams parallelization.
- **Next step**: If a DDD analysis exists (`docs/ddd-analysis.md`), run `/generalize-ddd-analysis`. Otherwise, if a flow catalog exists (`docs/requirements/flow-catalog.md`), run `/generalize-flows`. Otherwise, skip to `/decompose-services`.
