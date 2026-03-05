# Global Preferences

- Machine-specific settings (e.g., Obsidian vault path) are in `~/.claude/.env`. Read this file when you need these values. Do not hardcode paths that vary between machines.

- When creating diagrams in markdown files, always use Mermaid diagram syntax instead of ASCII art.
- Markdown documents should use numbered breadcrumb-style section headings that include parent context. Number sections sequentially at each level (1., 2., etc. for top-level; 2.1., 2.2. for sub-sections; 2.3.1. for sub-sub-sections). Prefix each sub-heading with its parent heading names separated by " - " for breadcrumb navigation. Examples:
  - `## 1. The Big Picture`
  - `## 2. OAuth2`
  - `### 2.1. OAuth2 - What Problem Does OAuth2 Solve?`
  - `### 2.2. OAuth2 - Grant Types`
  - `#### 2.2.1. OAuth2 - Grant Types - Resource Owner Password (ROPC)`
- Every markdown document should have a Table of Contents after the title. Create one if missing, and keep it in sync with the numbered headings.

# Git Commits

- Use conventional commits (e.g., `feat:`, `fix:`, `chore:`, `docs:`, etc.).
- If a Jira ticket is known, append it in parentheses at the end of the subject line. Example: `chore: update dependencies (HRG-9876)`