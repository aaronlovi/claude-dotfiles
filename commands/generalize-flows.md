---
description: "Create a platform-agnostic version of the flow catalog using the terminology mapping from generalized requirements"
argument-hint: <generalized-requirements-dir>
---

You are a senior architect creating a platform-agnostic version of an existing flow catalog. The original flow catalog captures the system's behavioral flows using project-specific terminology. The generalized requirements documents have already established a terminology mapping. Your job is to apply that mapping to produce a generalized flow catalog that is consistent with all downstream documents (service decomposition, Jira tasks, reviews).

## Input

$ARGUMENTS should be the path to the generalized requirements directory (e.g., `docs/generalized-requirements/`). If empty, look for `docs/generalized-requirements/`. If the target path does not exist, stop and tell the user.

## Prerequisites

**Required:** All three of the following must exist. If any is missing, stop and tell the user which document is needed.

1. **Original flow catalog** (`docs/requirements/flow-catalog.md`): The source document to generalize. This document is NEVER modified — it is preserved as a faithful record of the original system's flows.

2. **Generalized business requirements** (`docs/generalized-requirements/business-requirements.md`): Contains the terminology mapping in its "Traceability from Original Requirements" section. This is the authoritative source for term substitutions and the BR-* → GBR-* ID mapping.

3. **Generalized technical requirements** (`docs/generalized-requirements/technical-requirements.md`): Contains additional terminology mapping in its "Traceability from Original Requirements" section. This is the authoritative source for the TR-* → GTR-* ID mapping.

**Optional:** Generalized DDD analysis (`docs/generalized-requirements/ddd-analysis.md`). If present, cross-reference state machine terminology to ensure flow descriptions use the same generalized state names and transition labels.

## Process

### Phase 1: Build the Terminology Map

Read the "Traceability from Original Requirements" section (subsections "ID Mapping", "Terminology Changes — Domain Terms", and "Terminology Changes — Implementation/Framework Terms") from BOTH generalized requirements documents. Compile two mapping tables:

**Terminology map:**

| Original Term | Generalized Term | Source |
|---|---|---|
| *(from BR appendix)* | *(from BR appendix)* | business-requirements.md |
| *(from TR appendix)* | *(from TR appendix)* | technical-requirements.md |

**ID map:**

| Original ID | Generalized ID |
|---|---|
| BR-XXX-NN | GBR-NN |
| TR-XXX-NN | GTR-NN |

Include ALL categories of term changes: entity names, privilege names, enum values, procedure names, operator/vendor name removals, and implementation/framework term changes.

### Phase 2: Transform the Flow Catalog

Apply both the terminology map and the ID map to every section of the original flow catalog. Preserve all flow structures, step sequences, error conditions, and analysis — only change terminology and IDs. If a section is absent from the original flow catalog, omit it from the generalized version — do not generate sections that don't exist in the source.

**Sections requiring special attention:**

| Section | Transformation |
|---------|---------------|
| **Flow Summary table** | Replace BR-*/TR-* IDs with GBR-*/GTR-* equivalents. Replace domain-specific terms in Trigger and Actors columns. |
| **Overview tables** | Replace requirement IDs. Update domain-specific terms in Trigger, Actors, Preconditions, Postconditions. |
| **Inputs / Outputs tables** | Replace domain-specific type names and source/destination references. Keep structure intact. |
| **Happy Path tables** | Replace domain-specific terms in Action, System Response, and Data Changed columns. Preserve step numbering and actor assignments. |
| **Error Paths tables** | Replace domain-specific error codes and condition descriptions. Replace requirement references. |
| **Flow Interaction Matrix** | Replace flow names if they contained domain-specific terms. Update notes. |
| **Shared Error Patterns** | Replace domain-specific pattern names and requirement references. |
| **Requirement Coverage** | Replace all BR-*/TR-* IDs with GBR-*/GTR-* equivalents. If the generalized requirements merged or split original requirements, update the coverage mapping accordingly. |

### Phase 3: Cross-Reference with Generalized DDD Analysis

If `docs/generalized-requirements/ddd-analysis.md` exists:
- Verify that state names in flow steps match the generalized DDD analysis's state machine diagrams.
- Verify that actor/entity names match the generalized ubiquitous language glossary.
- If discrepancies are found, prefer the generalized DDD analysis terminology (it was established first).

### Phase 4: Verify Consistency

Before writing the output, verify:

| Check | What to Verify |
|-------|---------------|
| No original IDs remain | No BR-* or TR-* references in the output (except in parenthetical "(original: ...)" notes if needed for traceability) |
| No original-specific terms remain | No operator names, vendor names, domain-specific jargon, or implementation/framework-specific terms that were mapped in Phase 1 |
| ID references are valid | Every GBR-*/GTR-* ID referenced exists in the generalized requirements documents |
| Coverage is complete | Every GBR-* requirement from the generalized business requirements appears in at least one flow's Requirements list in the Requirement Coverage section, and every GBR-*/GTR-* ID referenced within the generalized flow catalog exists in the generalized requirements documents. Requirements listed in the generalized requirements' "Excluded from This Document" or "Extracted to Separate Services" sections are exempt from coverage. |

## Output Format

Write to `docs/generalized-requirements/flow-catalog.md`.

The document must use the same structure as the original flow catalog (see `/extract-flows` output format), with these additions:

1. A header note: "Generalized from [project-specific flow catalog](../requirements/flow-catalog.md) using terminology mappings from [business requirements](./business-requirements.md) and [technical requirements](./technical-requirements.md)."
2. An Appendix at the end:

```
## Appendix: Terminology Changes Applied

| Original Term | Generalized Term |
|---|---|
| ... | ... |

## Appendix: ID Mapping

| Original ID | Generalized ID |
|---|---|
| BR-XXX-NN | GBR-NN |
| TR-XXX-NN | GTR-NN |
```

## Self-Review

After producing the output artifact, follow the self-review convergence protocol in `commands/self-review-protocol.md` to iteratively refine the artifact until stable (max 5 passes).

## Important

- **Do NOT modify the original** `docs/requirements/flow-catalog.md`. It is a historical record of the project-specific flows.
- **Preserve all flow structures** — step counts, error path conditions, interaction matrices. Only change terminology and IDs, not the behavioral content.
- **Be comprehensive** — every section of the original must appear in the generalized version. Don't skip flows or abbreviate tables.
- **Keep the same level of detail** as the original. This is a terminology transformation, not a summarization.
- If the generalized requirements merged multiple original requirements into one (e.g., BR-USR-01 + BR-USR-02 → GBR-05), update the coverage section to reflect the merged ID.
- If the generalized requirements excluded some original requirements as domain-specific, flows that referenced those requirements should note the exclusion in the coverage section.
- This command produces a single synthesized output and does not support Agent Teams parallelization.
- **Next step**: Run `/decompose-services` to identify service boundaries (flow interaction analysis can inform boundary decisions).
