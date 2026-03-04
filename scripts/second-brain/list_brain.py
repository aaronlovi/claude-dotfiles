#!/usr/bin/env python3
"""
list_brain.py - List documents in the second brain

Usage:
    python list_brain.py                              # show all projects
    python list_brain.py --project identity-server    # filter by project
    python list_brain.py --type ddd                   # filter by doc type
    python list_brain.py --specificity generalized    # filter by specificity
"""

import argparse
from db import connect, TABLE

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="List documents in the second brain")
    parser.add_argument("--project", help="Filter by project name")
    parser.add_argument("--type", help="Filter by doc type (ddd, brd, trd, dataflow, jira, review, service, other)")
    parser.add_argument("--specificity", help="Filter by specificity (generalized, project_specific)")
    args = parser.parse_args()

    conn = connect()

    conditions = []
    params = []

    if args.project:
        conditions.append("project_name = %s")
        params.append(args.project)
    if args.type:
        conditions.append("doc_type = %s")
        params.append(args.type)
    if args.specificity:
        conditions.append("specificity = %s")
        params.append(args.specificity)

    where = f" WHERE {' AND '.join(conditions)}" if conditions else ""

    query = f"""
        SELECT project_name, doc_type, specificity,
               count(*) AS chunks,
               min(created_at)::date AS oldest,
               max(created_at)::date AS newest
        FROM {TABLE}
        {where}
        GROUP BY project_name, doc_type, specificity
        ORDER BY project_name, doc_type, specificity
    """

    rows = conn.execute(query, params).fetchall()
    conn.close()

    if not rows:
        print("No documents found.")
        return

    # Column headers and widths
    headers = ["Project", "Doc Type", "Specificity", "Chunks", "Oldest", "Newest"]
    col_widths = [len(h) for h in headers]

    formatted = []
    for row in rows:
        vals = [str(row[0]), str(row[1]), str(row[2]), str(row[3]), str(row[4]), str(row[5])]
        formatted.append(vals)
        for i, v in enumerate(vals):
            col_widths[i] = max(col_widths[i], len(v))

    # Print table
    header_line = "  ".join(h.ljust(col_widths[i]) for i, h in enumerate(headers))
    separator = "  ".join("-" * col_widths[i] for i in range(len(headers)))

    print(header_line)
    print(separator)
    for vals in formatted:
        print("  ".join(vals[i].ljust(col_widths[i]) for i in range(len(vals))))

    # Summary
    total_chunks = sum(r[3] for r in rows)
    total_groups = len(rows)
    projects = len(set(r[0] for r in rows))
    print(f"\n{total_chunks} chunks across {total_groups} groups in {projects} project(s)")


if __name__ == "__main__":
    main()
