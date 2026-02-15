# Claude Code Dotfiles

Global configuration, slash commands, and skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## What's Included

| Path | Description |
|------|-------------|
| `CLAUDE.md` | Global preferences (Mermaid diagrams, numbered headings, ToC conventions) |
| `settings.json` | Allowed tools and environment variables |
| `commands/` | 11 slash commands for a requirements-to-Jira pipeline |
| `skills/` | 4 skills for prompt management |
| `scripts/` | Maintenance scripts for reviewing/iterating on slash commands |

### Slash Commands

| Command | Purpose |
|---------|---------|
| `/extract-requirements` | Extract business and technical requirements from a codebase |
| `/extract-flows` | Catalog system flows with inputs, outputs, happy/error paths |
| `/ddd-analysis` | Domain-Driven Design analysis of a codebase |
| `/decompose-services` | Identify service boundaries from requirements |
| `/generate-jira-tasks` | Generate implementation-ordered Jira tasks |
| `/review-requirements` | Cross-document consistency review |
| `/generalize-requirements` | Create platform-agnostic versions of requirements |
| `/generalize-flows` | Create platform-agnostic flow catalog |
| `/generalize-ddd-analysis` | Create platform-agnostic DDD analysis |
| `/analyze-codebase` | Produce a reading-order guide for a codebase |
| `/pipeline` | Show the full pipeline stage order |

### Skills

| Skill | Purpose |
|-------|---------|
| `create-prompt` | Create a task prompt when work is clear and ready to implement |
| `create-meta-prompt` | Create research/plan workflow for complex tasks |
| `run-prompt` | Execute prompts from `.prompts/` |
| `prompt-rules` | Shared conventions for the prompt system |

## Installation

```bash
git clone https://github.com/aaronlovi/claude-dotfiles.git ~/dev/claude-dotfiles
cd ~/dev/claude-dotfiles
./install.sh
```

### Symlink mode (default)

Files are symlinked into `~/.claude`. Changes you make in either location are reflected immediately. This is the recommended mode for your primary machine.

### Copy mode

```bash
./install.sh --copy
```

Files are copied into `~/.claude`. Use this if you want a standalone install that doesn't depend on the repo location.

### Safety

- Existing files are backed up to `~/.claude/backup-<timestamp>/` before being replaced
- Files that are already correctly symlinked are skipped
- The script is idempotent -- safe to run multiple times

## Maintenance

The `scripts/review-slash-commands-loop.sh` script runs Claude in a loop to review and fix issues across all slash commands and skills, converging when no more changes are detected:

```bash
# Default: up to 5 iterations
./scripts/review-slash-commands-loop.sh

# Custom max iterations
./scripts/review-slash-commands-loop.sh 3
```

Review logs are saved to `scripts/review-logs/` (git-ignored).
