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
from db import connect, TABLE

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Clear the second brain")
    parser.add_argument("--project", help="Only clear a specific project")
    parser.add_argument("--force", action="store_true", help="Skip confirmation prompt")
    args = parser.parse_args()

    if args.project:
        target = f"all documents for project '{args.project}'"
    else:
        target = "ALL documents from the second brain"

    if not args.force:
        confirm = input(f"This will delete {target}. Continue? [y/N] ")
        if confirm.lower() != "y":
            print("Aborted.")
            sys.exit(0)

    conn = connect()

    if args.project:
        result = conn.execute(f"DELETE FROM {TABLE} WHERE project_name = %s", (args.project,))
    else:
        result = conn.execute(f"DELETE FROM {TABLE}")

    print(f"Deleted {result.rowcount} rows.")
    conn.close()

if __name__ == "__main__":
    main()
