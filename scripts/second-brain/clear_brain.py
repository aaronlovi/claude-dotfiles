#!/usr/bin/env python3
"""
clear_brain.py - Clear documents from the second brain

Usage:
    python clear_brain.py                          # clear everything (with confirmation)
    python clear_brain.py --project identity-server # clear one project
    python clear_brain.py --force                   # skip confirmation prompt
"""

import sys
import argparse
from supabase import create_client

# ── Configuration ─────────────────────────────────────────────────────────────

SUPABASE_URL = "http://localhost:8000"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"
TABLE_NAME = "project_knowledge"

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Clear the second brain")
    parser.add_argument("--project", help="Only clear a specific project")
    parser.add_argument("--force", action="store_true", help="Skip confirmation prompt")
    args = parser.parse_args()

    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

    # Describe what will be deleted
    if args.project:
        target = f"all documents for project '{args.project}'"
    else:
        target = "ALL documents from the second brain"

    if not args.force:
        confirm = input(f"This will delete {target}. Continue? [y/N] ")
        if confirm.lower() != "y":
            print("Aborted.")
            sys.exit(0)

    # Delete rows
    query = supabase.table(TABLE_NAME).delete()
    if args.project:
        query = query.eq("project_name", args.project)
    else:
        # Supabase requires a filter; match all rows via id > 0
        query = query.gt("id", 0)

    result = query.execute()
    count = len(result.data) if result.data else 0
    print(f"Deleted {count} rows.")

if __name__ == "__main__":
    main()
