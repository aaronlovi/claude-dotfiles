#!/usr/bin/env python3
"""
setup.py - Create the second_brain schema and project_knowledge table

Run once to initialize the database. Safe to re-run (uses IF NOT EXISTS).

Usage:
    python setup.py
"""

from db import connect, SCHEMA

SETUP_SQL = f"""
CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS {SCHEMA};

CREATE TABLE IF NOT EXISTS {SCHEMA}.project_knowledge (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_name text NOT NULL,
    doc_type text NOT NULL,
    specificity text NOT NULL DEFAULT 'project_specific',
    heading text NOT NULL,
    content text NOT NULL,
    embedding vector(384) NOT NULL,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS project_knowledge_embedding_idx
    ON {SCHEMA}.project_knowledge
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
"""

def main():
    conn = connect()
    print("Creating schema and table...")
    conn.execute(SETUP_SQL)
    print("Done.")
    conn.close()

if __name__ == "__main__":
    main()
