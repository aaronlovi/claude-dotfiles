Query the second brain for context relevant to the current task.

Run this command, capturing its full output:

```
python3 ~/.claude/scripts/second-brain/recall.py "$QUERY" $OPTIONS
```

Use the returned results as background context to inform your current task. The results come from documentation generated from past projects including DDD analyses, business requirements, technical requirements, data flow catalogs, and Jira task lists.

Available options to append to $OPTIONS:

- `--project <name>` to filter by project
- `--type <ddd|brd|trd|dataflow|jira|review|service>` to filter by doc type
- `--specificity <generalized|project_specific>` to filter by specificity
- `--limit <n>` to control number of results (default 5)

`--limit <n>` to control number of results (default 5)

## Query strategy: pick one

- **Is the question exhaustive?** ("which projects do X?", "does any project Y?", "list all Z?")
  Use the **per-project procedure** below. Skip the global search entirely.

- **Is the question specific/contextual?** ("how does project A do X?", "what is the rule for Y?")
  Run **2-3 complementary phrasings in parallel** globally with `--limit 10`, then merge and deduplicate by heading.

## Score interpretation

Each result includes a similarity score (0-1). Use this to judge quality:

| Score | Meaning |
|-------|---------|
| >= 0.45 | Strong match — high confidence |
| 0.30-0.44 | Moderate match — use with judgment |
| < 0.30 | Weak match — likely noise; treat with skepticism |

If all results score below 0.30, try rephrasing the query before drawing conclusions.

## Per-project procedure (exhaustive queries)

A single global search is not reliable for exhaustive questions because relevant results from some projects may rank below the limit. Instead:

1. Enumerate all known projects:

   python3 ~/.claude/scripts/second-brain/list_projects.py

2. Run the recall query once per project in parallel.
3. Aggregate results across all projects.
4. Explicitly call out which projects returned relevant results, and which did not — that is the answer to "which projects do NOT do X".

## Multi-phrasing strategy (specific queries only)

Semantic search is sensitive to terminology. For specific/contextual queries:

- Run 2-3 complementary phrasings in parallel (e.g. "SMS notification to players" and "Twilio messaging send_message").
- Merge results and deduplicate by heading before summarizing.
- Do not apply to exhaustive queries — the per-project procedure already guarantees coverage.

## When results are weak or absent

If the first round of queries returns no results or all scores are below 0.30:

1. Try alternative phrasings (different terminology, broader or narrower scope).
2. Try filtering by a relevant doc type (`--type brd`, `--type ddd`, etc.).
3. If still nothing, report that the second brain has no indexed content for this topic.

## After reading results

Summarize what relevant context you found. For exhaustive queries, explicitly state which projects had strong matches, which had only weak matches, and which had none.
