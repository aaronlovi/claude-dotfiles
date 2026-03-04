#!/usr/bin/env python3
"""
clear_brain.py - Clear documents from the second brain

Usage:
    python clear_brain.py                                    # clear everything (with confirmation)
    python clear_brain.py --project identity-server          # clear one project
    python clear_brain.py --type ddd                         # clear all DDD analysis docs
    python clear_brain.py --project myapp --type jira        # clear jira docs for one project
    python clear_brain.py --specificity generalized          # clear all generalized docs
    python clear_brain.py --force                            # skip confirmation prompt
"""

import sys
import argparse
from db import connect, TABLE

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Clear the second brain")
    parser.add_argument("--project", help="Only clear a specific project")
    parser.add_argument("--type", help="Only clear a specific doc type (ddd, brd, trd, dataflow, jira, review, service, other)")
    parser.add_argument("--specificity", help="Only clear a specificity level (generalized, project_specific)")
    parser.add_argument("--force", action="store_true", help="Skip confirmation prompt")
    args = parser.parse_args()

    conditions = []
    params = []
    parts = []

    if args.project:
        conditions.append("project_name = %s")
        params.append(args.project)
        parts.append(f"project '{args.project}'")
    if args.type:
        conditions.append("doc_type = %s")
        params.append(args.type)
        parts.append(f"type '{args.type}'")
    if args.specificity:
        conditions.append("specificity = %s")
        params.append(args.specificity)
        parts.append(f"specificity '{args.specificity}'")

    if parts:
        target = f"documents matching: {', '.join(parts)}"
    else:
        target = "ALL documents from the second brain"

    if not args.force:
        confirm = input(f"This will delete {target}. Continue? [y/N] ")
        if confirm.lower() != "y":
            print("Aborted.")
            sys.exit(0)

    conn = connect()

    where = f" WHERE {' AND '.join(conditions)}" if conditions else ""
    result = conn.execute(f"DELETE FROM {TABLE}{where}", params)

    print(f"Deleted {result.rowcount} rows.")
    conn.close()

if __name__ == "__main__":
    main()
