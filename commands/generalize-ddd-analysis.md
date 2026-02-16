---
description: "Create a platform-agnostic version of the DDD analysis using the terminology mapping from generalized requirements"
argument-hint: <generalized-requirements-dir>
---

You are a senior architect creating a platform-agnostic version of an existing DDD analysis. The original DDD analysis captures the codebase as-is, using domain-specific terminology. The generalized requirements documents have already established a terminology mapping. Your job is to apply that mapping to produce a generalized DDD analysis that is consistent with all downstream documents (service decomposition, Jira tasks, reviews).

## Input

$ARGUMENTS should be the path to the generalized requirements directory (e.g., `docs/generalized-requirements/`). If empty, look for `docs/generalized-requirements/`. If the target path does not exist, stop and tell the user.

## Prerequisites

**Required:** All three of the following must exist. If any is missing, stop and tell the user which document is needed.

1. **Original DDD analysis** (`docs/ddd-analysis.md`): The source document to generalize. This document is NEVER modified — it is preserved as a faithful record of the original codebase.

2. **Generalized business requirements** (`docs/generalized-requirements/business-requirements.md`): Contains the terminology mapping in its "Traceability from Original Requirements" section. This is the authoritative source for term substitutions.

3. **Generalized technical requirements** (`docs/generalized-requirements/technical-requirements.md`): Contains additional terminology mapping in its "Traceability from Original Requirements" section. Also the authoritative source for privilege name mappings.

## Process

### Phase 1: Build the Terminology Map

Read the "Traceability from Original Requirements" section (subsections "ID Mapping" and "Terminology Changes") from BOTH generalized requirements documents. Compile a single master mapping:

| Original Term | Generalized Term | Source |
|---|---|---|
| *(from BR appendix)* | *(from BR appendix)* | business-requirements.md |
| *(from TR appendix)* | *(from TR appendix)* | technical-requirements.md |

This table is your substitution guide. Every instance of an original term in the DDD analysis must be replaced with its generalized equivalent.

Also include ALL categories of term changes found in the traceability appendices:
- Privilege name changes
- Function/procedure name changes
- Enum value changes
- Entity/concept name changes
- Operator/license/vendor name removals (replace with "configurable" equivalents)

### Phase 2: Transform Each Section

Apply the terminology map to every section of the original DDD analysis. Preserve all assessments, conclusions, and structure — only change terminology. For code locations, keep originals as `(original: filename)` references.

**Sections requiring special attention:**

- **Ubiquitous Language** (MOST IMPORTANT): Replace every domain-specific term, update definitions, update ALL enum value lists. Remove platform-specific operator/license values (replace with "configurable" note). Add a note at the top: "This glossary uses platform-agnostic terminology. See [original DDD analysis](../ddd-analysis.md) for the codebase-specific terms."
- **State Machines**: Update ALL diagrams, transition tables, and invariant descriptions using the master terminology map. If the service decomposition extracted a subsystem that owns a state machine, note the extraction and apply this rule: remove the subsystem's detailed tactical pattern entries (entities, aggregates, repositories) and replace with a single summary row noting the extraction. Preserve the subsystem's entry in the bounded contexts section with a cross-reference to the service decomposition document.
- **Context Mapping**: Replace specific technology references where the generalized TRs use generic terms (e.g., "Debezium" → "CDC connector", "Kafka" → "message broker"). Keep pattern classifications unchanged (Customer-Supplier, ACL, etc.).
- **All other sections** (Executive Summary, Bounded Contexts, Tactical Patterns, Architectural Assessment, Recommendations): Apply terminology substitutions throughout. Preserve all coupling assessments, alignment ratings, and recommendation types.

### Phase 3: Cross-Reference with Service Decomposition

Check if `docs/generalized-requirements/service-decomposition.md` exists. If not, skip this phase entirely. (In the standard pipeline flow, the service decomposition does not yet exist at this stage. This phase applies when re-running generalize-ddd-analysis after service decomposition has been completed.)

If the file exists:
- Verify that the generalized DDD analysis's bounded context section is consistent with the service decomposition
- If the service decomposition extracted a subsystem (e.g., invitation codes) that the original DDD analysis kept together, add a note in the bounded contexts section referencing the service decomposition decision
- Update the "Potential Subdomain Separations" section to reflect any extraction decisions

### Phase 4: Verify Consistency

Before writing the output, verify:
1. Every privilege name in the generalized DDD analysis matches the privilege list in the generalized technical requirements' authorization section
2. Every enum value matches the generalized business requirements
3. No original-specific operator names, license names, or registry names remain in descriptive text (they may appear in parenthetical "original:" references)
4. State machine diagrams are consistent with the generalized requirements' state machine descriptions

## Output Format

Write to `docs/generalized-requirements/ddd-analysis.md`.

The document must include:
1. A header note: "Generalized from [original DDD analysis](../ddd-analysis.md) using terminology mappings from [business requirements](./business-requirements.md) and [technical requirements](./technical-requirements.md)."
2. The same section structure as the original DDD analysis
3. An Appendix: Terminology Changes Applied — listing every substitution made, for traceability

## Important

- **Do NOT modify the original** `docs/ddd-analysis.md`. It is a historical record of the codebase.
- **Preserve all DDD assessments** (alignment ratings, coupling assessments, recommendations). Only change terminology, not conclusions.
- **Keep code location references** as `(original: file:line)`, preserving the full path and line numbers from the original DDD analysis — a new implementation would use different filenames, but the references are still useful for tracing back to the original analysis.
- **Be comprehensive** — every section of the original must appear in the generalized version. Don't skip sections or abbreviate.
- **Keep the same level of detail** as the original. This is a terminology transformation, not a summarization.
- If the generalized requirements introduced NEW concepts that don't exist in the original DDD analysis (e.g., "Activity Limit" covers more than just poker game limits), note the expanded scope in the generalized version.
- This command produces a single synthesized output and does not support Agent Teams parallelization.
- **Next step**: If a project-specific flow catalog exists (`docs/requirements/flow-catalog.md`), run `/generalize-flows` to generalize it. Otherwise, skip to `/decompose-services`.
