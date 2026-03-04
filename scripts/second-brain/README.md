# Second Brain

Vector-search knowledge base for project documentation, powered by local Supabase and sentence-transformers.

## Table of Contents

- [1. Prerequisites](#1-prerequisites)
- [2. Database Setup](#2-database-setup)
  - [2.1. Database Setup - Enable pgvector](#21-database-setup---enable-pgvector)
  - [2.2. Database Setup - Create Table](#22-database-setup---create-table)
  - [2.3. Database Setup - Create Search Function](#23-database-setup---create-search-function)
- [3. Python Dependencies](#3-python-dependencies)
- [4. Scripts](#4-scripts)
  - [4.1. Scripts - ingest.py](#41-scripts---ingestpy)
  - [4.2. Scripts - recall.py](#42-scripts---recallpy)
  - [4.3. Scripts - clear_brain.py](#43-scripts---clear_brainpy)
- [5. Claude Code Integration](#5-claude-code-integration)

## 1. Prerequisites

- Local Supabase instance running on `http://localhost:8000`
- Python 3.10+

## 2. Database Setup

Run these SQL statements in the Supabase SQL editor to create the schema from scratch.

### 2.1. Database Setup - Enable pgvector

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### 2.2. Database Setup - Create Table

```sql
CREATE TABLE project_knowledge (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_name text NOT NULL,
    doc_type text NOT NULL,
    specificity text NOT NULL DEFAULT 'project_specific',
    heading text NOT NULL,
    content text NOT NULL,
    embedding vector(384) NOT NULL,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX ON project_knowledge USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
```

The embedding dimension (384) matches the `all-MiniLM-L6-v2` model used by `ingest.py`.

### 2.3. Database Setup - Create Search Function

```sql
CREATE OR REPLACE FUNCTION match_documents_filtered(
    query_embedding vector(384),
    match_count int,
    filter_project text DEFAULT NULL,
    filter_doc_type text DEFAULT NULL,
    filter_specificity text DEFAULT NULL
)
RETURNS TABLE (
    project_name text,
    doc_type text,
    specificity text,
    heading text,
    content text,
    similarity float
) AS $$
    SELECT
        d.project_name,
        d.doc_type,
        d.specificity,
        d.heading,
        d.content,
        1 - (d.embedding <=> query_embedding) AS similarity
    FROM project_knowledge d
    WHERE (filter_project IS NULL OR d.project_name = filter_project)
        AND (filter_doc_type IS NULL OR d.doc_type = filter_doc_type)
        AND (filter_specificity IS NULL OR d.specificity = filter_specificity)
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
$$ LANGUAGE sql;
```

## 3. Python Dependencies

```bash
pip install sentence-transformers supabase
```

## 4. Scripts

### 4.1. Scripts - ingest.py

Ingest markdown documentation into the knowledge base. Splits files by heading into chunks and generates embeddings.

```bash
python ingest.py <project_docs_path> <project_name>

# Example
python ingest.py ~/dev/myproject/docs my-project
```

Documents are auto-classified by filename pattern:

| Doc type   | Filename pattern            |
|------------|-----------------------------|
| ddd        | `ddd-analysis*`             |
| brd        | `business-requirements*`    |
| trd        | `technical-requirements*`   |
| dataflow   | `flow-catalog*`             |
| jira       | `jira-*`                    |
| review     | `review-findings*`          |
| service    | `service-decomposition*`    |
| other      | everything else             |

Documents under a `generalized-requirements/` directory are tagged with specificity `generalized`; all others are `project_specific`.

### 4.2. Scripts - recall.py

Query the knowledge base using natural language. Returns the most similar chunks ranked by cosine similarity.

```bash
python recall.py <query> [options]

# Examples
python recall.py "authentication patterns"
python recall.py "deposit limit rules" --project slots-app
python recall.py "bounded contexts" --type ddd --limit 3
python recall.py "service boundaries" --specificity generalized
```

| Option          | Description                                      |
|-----------------|--------------------------------------------------|
| `--project`     | Filter by project name                           |
| `--type`        | Filter by doc type                               |
| `--specificity` | Filter by `generalized` or `project_specific`    |
| `--limit`       | Number of results (default: 5)                   |

### 4.3. Scripts - clear_brain.py

Delete documents from the knowledge base.

```bash
python clear_brain.py                             # clear everything (with confirmation)
python clear_brain.py --project identity-server   # clear one project
python clear_brain.py --force                     # skip confirmation
```

## 5. Claude Code Integration

The recall script is wired into Claude Code via:

- **Slash command**: `/recall` — runs `recall.py` with the query and options
- **Meta-prompt skill**: `create-meta-prompt` queries the second brain automatically before generating research/plan prompts
