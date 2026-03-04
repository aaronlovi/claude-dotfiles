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

After reading the results, summarize what relevant context you found before proceeding with the task.
