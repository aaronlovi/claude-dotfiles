# Global Preferences

- Machine-specific settings (e.g., Obsidian vault path) are in `~/.claude/.env`. Read this file when you need these values. Do not hardcode paths that vary between machines.

- When creating diagrams in markdown files, always use Mermaid diagram syntax instead of ASCII art. In Mermaid node labels, use `<br>` for line breaks — never `\n`.
- Markdown documents should use numbered breadcrumb-style section headings that include parent context. Number sections sequentially at each level (1., 2., etc. for top-level; 2.1., 2.2. for sub-sections; 2.3.1. for sub-sub-sections). Prefix each sub-heading with its parent heading names separated by " - " for breadcrumb navigation. Examples:
  - `## 1. The Big Picture`
  - `## 2. OAuth2`
  - `### 2.1. OAuth2 - What Problem Does OAuth2 Solve?`
  - `### 2.2. OAuth2 - Grant Types`
  - `#### 2.2.1. OAuth2 - Grant Types - Resource Owner Password (ROPC)`
- Every markdown document should have a Table of Contents after the title. Create one if missing, and keep it in sync with the numbered headings.
- For Obsidian markdown TOC links, prefer wikilink format — it requires no encoding: `[[#Heading Text|Display Text]]`. When standard markdown links are needed instead, compute anchors programmatically: space→`%20`, `(`→`%28`, `)`→`%29`, `/`→`%2F`, non-ASCII→percent-encode UTF-8 bytes (e.g. em-dash `—`→`%E2%80%94`); ASCII letters/digits/`.-_:,+` pass through unchanged. Never hand-write anchors for headings containing parens, slashes, or non-ASCII — always compute and audit them.
- In Mermaid `stateDiagram-v2`, transition labels (after `-->  :`) must not contain colons (`:`), `<br>` tags, or other special punctuation. Only one colon is allowed per transition line (the label separator). Use plain prose labels; put detail in the table below the diagram.

## Tools

- `~/bin/clip-image [name]` saves the Windows clipboard image to `/tmp/<name>.png`. Use this freely without asking permission whenever the user says they have a screenshot or image to share.

## Elixir Projects

- In Ecto migrations, add Postgres `COMMENT ON TABLE` and `COMMENT ON COLUMN` for every table and column. Use `execute("COMMENT ON ...", "SELECT 1")` inside `change/0` for reversibility.

# Git Commits

- Use conventional commits (e.g., `feat:`, `fix:`, `chore:`, `docs:`, etc.).
- If a Jira ticket is known, append it in parentheses at the end of the subject line. Example: `chore: update dependencies (HRG-9876)`
