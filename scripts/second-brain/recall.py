#!/usr/bin/env python3
"""
recall.py - Query the second brain for relevant context

Usage:
    python recall.py <query> [options]

Options:
    --project       Filter by project name              (e.g. --project identity-server)
    --type          Filter by doc type                  (e.g. --type ddd)
    --specificity   Filter by specificity               (e.g. --specificity generalized)
    --limit         Number of results to return         (default: 5)

Examples:
    python recall.py "authentication patterns"
    python recall.py "deposit limit rules" --project slots-app
    python recall.py "bounded contexts" --type ddd --limit 3
    python recall.py "service boundaries" --specificity generalized
    python recall.py "password hashing" --project identity-server --specificity generalized --type trd

Doc types:      ddd, brd, trd, dataflow, jira, review, service, other
Specificity:    generalized, project_specific
"""

import sys
import argparse
from sentence_transformers import SentenceTransformer
from db import connect, TABLE

EMBEDDING_MODEL = "all-MiniLM-L6-v2"

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Query the second brain")
    parser.add_argument("query", help="Natural language query")
    parser.add_argument("--project", help="Filter by project name")
    parser.add_argument("--type", dest="doc_type", help="Filter by doc type")
    parser.add_argument("--specificity", choices=["generalized", "project_specific"],
                        help="Filter by specificity (generalized or project_specific)")
    parser.add_argument("--limit", type=int, default=5, help="Number of results (default: 5)")
    args = parser.parse_args()

    model = SentenceTransformer(EMBEDDING_MODEL)
    query_embedding = model.encode(args.query).tolist()

    conn = connect()

    conditions = []
    filter_params: list = []

    if args.project:
        conditions.append("project_name = %s")
        filter_params.append(args.project)
    if args.doc_type:
        conditions.append("doc_type = %s")
        filter_params.append(args.doc_type)
    if args.specificity:
        conditions.append("specificity = %s")
        filter_params.append(args.specificity)

    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    embedding_str = str(query_embedding)

    # Param order must match SQL: SELECT %s, WHERE %s..., ORDER BY %s, LIMIT %s
    params = [embedding_str, *filter_params, embedding_str, args.limit]

    rows = conn.execute(
        f"""SELECT project_name, doc_type, specificity, heading, content,
                   1 - (embedding <=> %s::vector) AS similarity
            FROM {TABLE}
            {where}
            ORDER BY embedding <=> %s::vector
            LIMIT %s""",
        params,
    ).fetchall()

    conn.close()

    if not rows:
        print("No results found.")
        sys.exit(0)

    print(f"=== Second Brain: {len(rows)} results for \"{args.query}\" ===\n")

    for i, row in enumerate(rows, 1):
        print(f"--- Result {i} ---")
        print(f"Project:      {row[0]}")
        print(f"Type:         {row[1]}")
        print(f"Specificity:  {row[2]}")
        print(f"Heading:      {row[3]}")
        print(f"Score:        {row[5]:.3f}")
        print()
        print(row[4])
        print()

if __name__ == "__main__":
    main()
