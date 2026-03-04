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
from supabase import create_client

# ── Configuration ─────────────────────────────────────────────────────────────

SUPABASE_URL = "http://localhost:8000"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"
EMBEDDING_MODEL = "all-MiniLM-L6-v2"
TABLE_NAME = "project_knowledge"

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

    # Load model and generate query embedding
    model = SentenceTransformer(EMBEDDING_MODEL)
    query_embedding = model.encode(args.query).tolist()

    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

    params = {
        "query_embedding": query_embedding,
        "match_count": args.limit,
    }

    if args.project:
        params["filter_project"] = args.project
    if args.doc_type:
        params["filter_doc_type"] = args.doc_type
    if args.specificity:
        params["filter_specificity"] = args.specificity

    results = supabase.rpc("match_documents_filtered", params).execute()

    if not results.data:
        print("No results found.")
        sys.exit(0)

    # Output results in a format Claude Code can use as context
    print(f"=== Second Brain: {len(results.data)} results for \"{args.query}\" ===\n")

    for i, row in enumerate(results.data, 1):
        print(f"--- Result {i} ---")
        print(f"Project:      {row['project_name']}")
        print(f"Type:         {row['doc_type']}")
        print(f"Specificity:  {row['specificity']}")
        print(f"Heading:      {row['heading']}")
        print(f"Score:        {row['similarity']:.3f}")
        print()
        print(row["content"])
        print()

if __name__ == "__main__":
    main()
