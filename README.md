# Claude Code Dotfiles

Global configuration, slash commands, and skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## What's Included

| Path | Description |
|------|-------------|
| `CLAUDE.md` | Global preferences (Mermaid diagrams, numbered headings, ToC conventions) |
| `settings.json` | Allowed tools and environment variables |
| `commands/` | 14 slash commands — a requirements-to-Jira pipeline plus second brain integration |
| `skills/` | 7 skills — prompt management, code review, and task wrap-up |
| `scripts/` | Second brain management scripts and maintenance utilities |

### Slash Commands

Commands are listed in pipeline stage order. Run `/pipeline` to see the full sequence.

| Command | Stage | Purpose |
|---------|-------|---------|
| `/ddd-analysis` | 1 | Domain-Driven Design analysis of a codebase |
| `/analyze-codebase` | 2 | Produce a reading-order guide for a codebase |
| `/extract-requirements` | 3 | Extract business and technical requirements from a codebase |
| `/extract-flows` | 3b | Catalog system flows with inputs, outputs, happy/error paths |
| `/generalize-requirements` | 4 | Create platform-agnostic versions of requirements |
| `/generalize-ddd-analysis` | 4b | Create platform-agnostic DDD analysis |
| `/generalize-flows` | 4c | Create platform-agnostic flow catalog |
| `/decompose-services` | 5 | Identify service boundaries from requirements |
| `/generate-jira-tasks` | 6 | Generate implementation-ordered Jira tasks |
| `/review-requirements` | 7 | Cross-document consistency review |
| `/ingest-second-brain` | 8 | Ingest pipeline documents into the second brain |
| `/recall` | — | Query the second brain for relevant context |
| `/self-review-protocol` | — | Self-review convergence protocol for output quality |
| `/pipeline` | — | Show the full pipeline stage order |

### Skills

| Skill | Purpose |
|-------|---------|
| `create-prompt` | Create a task prompt when work is clear and ready to implement |
| `create-meta-prompt` | Create research/plan workflow for complex tasks |
| `run-prompt` | Execute prompts from `.prompts/` |
| `prompt-rules` | Shared conventions for the prompt system (not user-invocable) |
| `review-squashed-changes` | Review all code changes in a squashed commit on top of origin/main |
| `review-copilot-comments` | Triage GitHub Copilot code review comments on the current PR |
| `wrap-up` | Final sweep of a completed task — checks for loose ends and fixes them |

## Installation

```bash
git clone https://github.com/aaronlovi/claude-dotfiles.git ~/dev/claude-dotfiles
cd ~/dev/claude-dotfiles
./install.sh
```

After installation, copy `.env.example` to `~/.claude/.env` and configure machine-specific settings (e.g., `OBSIDIAN_VAULT` path for pipeline output). This is separate from the database `.env` described in the Second Brain section below.

### Symlink mode (default)

Files are symlinked into `~/.claude`. Changes you make in either location are reflected immediately. This is the recommended mode for your primary machine.

### Copy mode

```bash
./install.sh --copy
```

Files are copied into `~/.claude`. Use this if you want a standalone install that doesn't depend on the repo location.

### Uninstall

```bash
./uninstall.sh
```

Only removes symlinks that point back to this repo. Non-symlinked files (from `--copy` installs) are left untouched with a warning. User files like `~/.claude/.env` are never removed.

### Safety

- Existing files are backed up to `~/.claude/backup-<timestamp>/` before being replaced
- Files that are already correctly symlinked are skipped
- The script is idempotent — safe to run multiple times

## Second Brain (PostgreSQL + pgvector)

The second brain stores semantic embeddings of pipeline output for `/recall` queries. It requires PostgreSQL with the `pgvector` extension and a few Python packages.

### Prerequisites

```bash
pip install psycopg python-dotenv sentence-transformers
```

### Database Setup

Use the following `docker-compose.yml` (or add the postgres service to an existing compose file):

```yaml
name: global_infra

services:
  postgres:
    image: pgvector/pgvector:pg17
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-postgres}
    ports:
      - "${POSTGRES_PORT:-5456}:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

Start it and initialize the schema:

```bash
docker compose up -d
cd scripts/second-brain
cp .env.example .env        # edit if you changed ports/credentials
python3 setup.py
```

The database `.env` at `scripts/second-brain/.env` configures the connection (host, port, user, password, database). The defaults match the `docker-compose.yml` above.

### Management

Use the menu-driven interface to list, ingest, query, and delete documents:

```bash
./scripts/second-brain/brain.sh
```

## Maintenance

The `scripts/review-slash-commands-loop.sh` script runs Claude in a loop to review and fix issues across all slash commands and skills, converging when no more changes are detected:

```bash
# Default: up to 5 iterations
./scripts/review-slash-commands-loop.sh

# Custom max iterations
./scripts/review-slash-commands-loop.sh 3
```

Review logs are saved to `scripts/review-logs/` (git-ignored).
