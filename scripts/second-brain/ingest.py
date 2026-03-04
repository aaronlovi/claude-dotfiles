#!/usr/bin/env python3
"""
ingest.py - Ingest project documentation into the second brain

Usage:
    python ingest.py <project_docs_path> <project_name> [--append]

By default, existing data for the project is deleted before ingesting.
Use --append to keep existing data and add new chunks alongside it.

Example:
    python ingest.py ~/dev/4poker-code/backend/identity-server/docs identity-server
    python ingest.py ~/dev/myproject/docs my-project --append
"""

import sys
import re
import argparse
from pathlib import Path
from sentence_transformers import SentenceTransformer
from db import connect, TABLE

EMBEDDING_MODEL = "all-MiniLM-L6-v2"

# ── Doc type detection ────────────────────────────────────────────────────────

DOC_TYPE_PATTERNS = [
    ("ddd",      r"ddd[-_]analysis"),
    ("brd",      r"business[-_]requirements"),
    ("trd",      r"technical[-_]requirements"),
    ("dataflow", r"flow[-_]catalog"),
    ("jira",     r"jira[-_]"),
    ("review",   r"review[-_]findings"),
    ("service",  r"service[-_]decomposition"),
    ("other",    r".*"),  # fallback
]

def detect_doc_type(filename: str) -> str:
    name = filename.lower()
    for doc_type, pattern in DOC_TYPE_PATTERNS:
        if re.search(pattern, name):
            return doc_type
    return "other"

# ── Specificity detection ─────────────────────────────────────────────────────

def detect_specificity(rel_path: Path) -> str:
    """Detect whether a doc is generalized or project-specific based on its path."""
    parts = [p.lower() for p in rel_path.parts]
    if "generalized-requirements" in parts:
        return "generalized"
    return "project_specific"

# ── Chunking ──────────────────────────────────────────────────────────────────

def chunk_by_heading(content: str, min_chunk_size: int = 100) -> list[dict]:
    """Split markdown into chunks by heading, returning list of {heading, content}."""
    chunks = []
    current_heading = "Introduction"
    current_lines = []

    for line in content.splitlines():
        if re.match(r"^#{1,3}\s+", line):
            # Save previous chunk if it has enough content
            text = "\n".join(current_lines).strip()
            if len(text) >= min_chunk_size:
                chunks.append({"heading": current_heading, "content": text})
            current_heading = line.lstrip("#").strip()
            current_lines = []
        else:
            current_lines.append(line)

    # Save final chunk
    text = "\n".join(current_lines).strip()
    if len(text) >= min_chunk_size:
        chunks.append({"heading": current_heading, "content": text})

    return chunks

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Ingest project documentation into the second brain")
    parser.add_argument("docs_path", help="Path to the project docs directory")
    parser.add_argument("project_name", help="Project name for tagging")
    parser.add_argument("--append", action="store_true",
                        help="Keep existing data instead of replacing it")
    args = parser.parse_args()

    docs_path = Path(args.docs_path).expanduser().resolve()
    project_name = args.project_name

    if not docs_path.exists():
        print(f"Error: docs path does not exist: {docs_path}")
        sys.exit(1)

    print(f"Project:    {project_name}")
    print(f"Docs path:  {docs_path}")
    print(f"Loading embedding model...")

    model = SentenceTransformer(EMBEDDING_MODEL)
    conn = connect()

    if not args.append:
        result = conn.execute(f"DELETE FROM {TABLE} WHERE project_name = %s", (project_name,))
        if result.rowcount > 0:
            print(f"Cleared {result.rowcount} existing rows for '{project_name}'")

    # Find all markdown files recursively
    md_files = list(docs_path.rglob("*.md"))
    print(f"Found {len(md_files)} markdown files\n")

    total_chunks = 0
    skipped_files = 0

    for md_file in sorted(md_files):
        rel_path = md_file.relative_to(docs_path)
        doc_type = detect_doc_type(md_file.name)
        specificity = detect_specificity(rel_path)

        content = md_file.read_text(encoding="utf-8")
        chunks = chunk_by_heading(content)

        if not chunks:
            print(f"  skip (too small): {rel_path}")
            skipped_files += 1
            continue

        print(f"  ingesting [{doc_type:8}] [{specificity:16}] {rel_path} ({len(chunks)} chunks)")

        for chunk in chunks:
            embedding = model.encode(chunk["content"]).tolist()

            conn.execute(
                f"""INSERT INTO {TABLE}
                    (project_name, doc_type, specificity, heading, content, embedding)
                    VALUES (%s, %s, %s, %s, %s, %s)""",
                (project_name, doc_type, specificity,
                 chunk["heading"], chunk["content"], str(embedding)),
            )

            total_chunks += 1

    conn.close()
    print(f"\nDone. Ingested {total_chunks} chunks from {len(md_files) - skipped_files} files.")
    print(f"Skipped {skipped_files} files (too small or empty).")

if __name__ == "__main__":
    main()
