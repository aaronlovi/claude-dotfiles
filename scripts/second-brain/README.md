# Second Brain

Vector-search knowledge base for project documentation, powered by PostgreSQL + pgvector and sentence-transformers.

## Table of Contents

- [1. Prerequisites](#1-prerequisites)
- [2. PostgreSQL + pgvector](#2-postgresql--pgvector)
- [3. Configuration](#3-configuration)
- [4. Python Dependencies](#4-python-dependencies)
- [5. Database Setup](#5-database-setup)
  - [5.1. Database Setup - Automated](#51-database-setup---automated)
  - [5.2. Database Setup - Manual SQL](#52-database-setup---manual-sql)
- [6. Scripts](#6-scripts)
  - [6.1. Scripts - ingest.py](#61-scripts---ingestpy)
  - [6.2. Scripts - recall.py](#62-scripts---recallpy)
  - [6.3. Scripts - clear_brain.py](#63-scripts---clear_brainpy)
- [7. Claude Code Integration](#7-claude-code-integration)

## 1. Prerequisites

- PostgreSQL with the pgvector extension (see step 2)
- Python 3.10+

## 2. PostgreSQL + pgvector

The Docker image for PostgreSQL must include pgvector. In `~/tools/infra/.env`, set:

```
POSTGRES_IMAGE=pgvector/pgvector:pg17
```

Then recreate the container:

```bash
cd ~/tools/infra
docker compose up -d postgres
```

This is a drop-in replacement for `postgres:17-alpine` — existing data volumes are preserved.

For native Postgres installs, see [pgvector installation docs](https://github.com/pgvector/pgvector#installation).

## 3. Configuration

Copy the example env file and edit as needed:

```bash
cp .env.example .env
```

The `.env` file lives in this directory and is git-ignored. Variables:

| Variable                  | Default     | Description          |
|---------------------------|-------------|----------------------|
| `SECOND_BRAIN_DB_HOST`    | `localhost` | PostgreSQL host      |
| `SECOND_BRAIN_DB_PORT`    | `5456`      | PostgreSQL port      |
| `SECOND_BRAIN_DB_USER`    | `postgres`  | PostgreSQL user      |
| `SECOND_BRAIN_DB_PASSWORD`| `postgres`  | PostgreSQL password  |
| `SECOND_BRAIN_DB_NAME`    | `postgres`  | Database name        |

## 4. Python Dependencies

On Debian/Ubuntu (including WSL), install system-wide:

```bash
pip install --break-system-packages psycopg python-dotenv sentence-transformers
```

## 5. Database Setup

All objects live in the `second_brain` schema to keep them isolated from other data in the same database.

### 5.1. Database Setup - Automated

```bash
python setup.py
```

This creates the schema, table, and index. Safe to re-run.

### 5.2. Database Setup - Manual SQL

If you prefer to run the SQL directly:

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS second_brain;

CREATE TABLE IF NOT EXISTS second_brain.project_knowledge (
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
    ON second_brain.project_knowledge
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
```

The embedding dimension (384) matches the `all-MiniLM-L6-v2` model used by `ingest.py`.

## 6. Scripts

### 6.1. Scripts - ingest.py

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

### 6.2. Scripts - recall.py

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

### 6.3. Scripts - clear_brain.py

Delete documents from the knowledge base.

```bash
python clear_brain.py                             # clear everything (with confirmation)
python clear_brain.py --project identity-server   # clear one project
python clear_brain.py --force                     # skip confirmation
```

## 7. Claude Code Integration

The recall script is wired into Claude Code via:

- **Slash command**: `/recall` — runs `recall.py` with the query and options
- **Meta-prompt skill**: `create-meta-prompt` queries the second brain automatically before generating research/plan prompts
