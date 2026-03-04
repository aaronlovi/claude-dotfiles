#!/usr/bin/env python3
"""
ingest.py - Ingest project documentation into Supabase second brain

Usage:
    python ingest.py <project_docs_path> <project_name>

Example:
    python ingest.py ~/dev/4poker-code/backend/identity-server/docs identity-server
"""

import sys
import os
import re
from pathlib import Path
from sentence_transformers import SentenceTransformer
from supabase import create_client

# ── Configuration ────────────────────────────────────────────────────────────

SUPABASE_URL = "http://localhost:8000"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE"
EMBEDDING_MODEL = "all-MiniLM-L6-v2"
TABLE_NAME = "project_knowledge"

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
    if len(sys.argv) < 3:
        print("Usage: ingest.py <project_docs_path> <project_name>")
        print("Example: ingest.py ~/dev/myproject/docs my-project")
        sys.exit(1)

    docs_path = Path(sys.argv[1]).expanduser().resolve()
    project_name = sys.argv[2]

    if not docs_path.exists():
        print(f"Error: docs path does not exist: {docs_path}")
        sys.exit(1)

    print(f"Project:    {project_name}")
    print(f"Docs path:  {docs_path}")
    print(f"Loading embedding model...")

    model = SentenceTransformer(EMBEDDING_MODEL)
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

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
            # Generate embedding
            embedding = model.encode(chunk["content"]).tolist()

            # Upsert into Supabase
            supabase.table(TABLE_NAME).insert({
                "project_name": project_name,
                "doc_type": doc_type,
                "specificity": specificity,
                "heading": chunk["heading"],
                "content": chunk["content"],
                "embedding": embedding,
            }).execute()

            total_chunks += 1

    print(f"\nDone. Ingested {total_chunks} chunks from {len(md_files) - skipped_files} files.")
    print(f"Skipped {skipped_files} files (too small or empty).")

if __name__ == "__main__":
    main()
