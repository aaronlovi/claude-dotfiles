#!/usr/bin/env bash
#
# brain.sh - Menu-driven interface for second brain management
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON=python3
CLAUDE_ENV="$HOME/.claude/.env"

# ── Helpers ───────────────────────────────────────────────────────────────────

run_py() { "$PYTHON" "$SCRIPT_DIR/$1" "${@:2}"; }

resolve_vault_path() {
    if [[ ! -f "$CLAUDE_ENV" ]]; then
        echo "Error: $CLAUDE_ENV not found. Copy .env.example to ~/.claude/.env first." >&2
        return 1
    fi
    local vault
    vault=$(grep '^OBSIDIAN_VAULT=' "$CLAUDE_ENV" | cut -d= -f2-)
    if [[ -z "$vault" ]]; then
        echo "Error: OBSIDIAN_VAULT not set in $CLAUDE_ENV." >&2
        return 1
    fi
    echo "$vault"
}

resolve_project_name() {
    local toplevel
    toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "Error: not in a git repository. cd into a project first, or use manual ingest." >&2
        return 1
    }
    basename "$toplevel"
}

prompt_value() {
    local label="$1" default="${2:-}"
    local hint=""
    [[ -n "$default" ]] && hint=" [$default]"
    read -rp "$label$hint: " value
    echo "${value:-$default}"
}

prompt_optional() {
    local label="$1"
    read -rp "$label (leave blank to skip): " value
    echo "$value"
}

pause() {
    echo
    read -rp "Press Enter to continue..."
}

# ── Menu Actions ──────────────────────────────────────────────────────────────

do_list() {
    echo
    echo "=== List Documents ==="
    echo
    local project type specificity
    project=$(prompt_optional "Filter by project")
    type=$(prompt_optional "Filter by doc type (ddd/brd/trd/dataflow/jira/review/service/other)")
    specificity=$(prompt_optional "Filter by specificity (generalized/project_specific)")

    local args=()
    [[ -n "$project" ]]     && args+=(--project "$project")
    [[ -n "$type" ]]        && args+=(--type "$type")
    [[ -n "$specificity" ]] && args+=(--specificity "$specificity")

    echo
    run_py list_brain.py "${args[@]}"
    pause
}

do_ingest_pipeline() {
    echo
    echo "=== Ingest Pipeline Output ==="
    echo

    local vault project docs_path
    vault=$(resolve_vault_path) || { pause; return; }
    project=$(resolve_project_name) || { pause; return; }
    docs_path="$vault/Pipeline/$project"

    if [[ ! -d "$docs_path" ]]; then
        echo "Error: $docs_path does not exist."
        echo "Run the pipeline stages first to generate output."
        pause
        return
    fi

    local md_count
    md_count=$(find "$docs_path" -name '*.md' | wc -l)
    if [[ "$md_count" -eq 0 ]]; then
        echo "Error: no .md files found in $docs_path."
        pause
        return
    fi

    echo "Project:  $project"
    echo "Path:     $docs_path"
    echo "Files:    $md_count markdown file(s)"
    echo "Mode:     replace (deletes old chunks first)"
    echo

    read -rp "Proceed? [Y/n] " confirm
    [[ "$confirm" =~ ^[nN] ]] && echo "Aborted." && pause && return

    echo
    run_py ingest.py "$docs_path" "$project"
    pause
}

do_ingest() {
    echo
    echo "=== Ingest Documents (Manual) ==="
    echo
    local docs_path project mode
    docs_path=$(prompt_value "Path to docs directory")
    [[ -z "$docs_path" ]] && echo "Path is required." && pause && return

    project=$(prompt_value "Project name")
    [[ -z "$project" ]] && echo "Project name is required." && pause && return

    mode=$(prompt_optional "Mode: replace (default) or append")

    local args=("$docs_path" "$project")
    [[ "$mode" == "append" ]] && args+=(--append)

    echo
    run_py ingest.py "${args[@]}"
    pause
}

do_recall() {
    echo
    echo "=== Query Second Brain ==="
    echo
    local query project type specificity limit
    query=$(prompt_value "Search query")
    [[ -z "$query" ]] && echo "Query is required." && pause && return

    project=$(prompt_optional "Filter by project")
    type=$(prompt_optional "Filter by doc type")
    specificity=$(prompt_optional "Filter by specificity")
    limit=$(prompt_optional "Number of results (default: 5)")

    local args=("$query")
    [[ -n "$project" ]]     && args+=(--project "$project")
    [[ -n "$type" ]]        && args+=(--type "$type")
    [[ -n "$specificity" ]] && args+=(--specificity "$specificity")
    [[ -n "$limit" ]]       && args+=(--limit "$limit")

    echo
    run_py recall.py "${args[@]}"
    pause
}

do_delete() {
    echo
    echo "=== Delete Documents ==="
    echo
    echo "Tip: run List first to see what's in the database."
    echo
    local project type specificity
    project=$(prompt_optional "Filter by project")
    type=$(prompt_optional "Filter by doc type (ddd/brd/trd/dataflow/jira/review/service/other)")
    specificity=$(prompt_optional "Filter by specificity (generalized/project_specific)")

    local args=()
    [[ -n "$project" ]]     && args+=(--project "$project")
    [[ -n "$type" ]]        && args+=(--type "$type")
    [[ -n "$specificity" ]] && args+=(--specificity "$specificity")

    # Show what will be affected first
    echo
    echo "Documents matching these filters:"
    echo
    run_py list_brain.py "${args[@]}"
    echo

    # clear_brain.py handles its own confirmation prompt
    run_py clear_brain.py "${args[@]}"
    pause
}

do_clear_all() {
    echo
    echo "=== Clear All Documents ==="
    echo
    echo "This will delete EVERYTHING from the second brain."
    echo
    run_py clear_brain.py
    pause
}

do_setup() {
    echo
    echo "=== Initialize Database ==="
    echo
    run_py setup.py
    pause
}

# ── Main Menu ─────────────────────────────────────────────────────────────────

main_menu() {
    while true; do
        clear
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║                      Second Brain Manager                     ║"
        echo "╠════════════════════════════════════════════════════════════════╣"
        echo "║                                                               ║"
        echo "║  1) List documents                                            ║"
        echo "║     Browse what's stored, grouped by project and doc type.    ║"
        echo "║     Shows chunk counts and date ranges. Filterable.           ║"
        echo "║                                                               ║"
        echo "║  2) Ingest pipeline output                                    ║"
        echo "║     Auto-detect project name and vault path from the current  ║"
        echo "║     git repo and ~/.claude/.env. One-step ingest.             ║"
        echo "║                                                               ║"
        echo "║  3) Ingest documents (manual)                                 ║"
        echo "║     Load markdown files from any directory into the database. ║"
        echo "║     Specify path and project name manually.                   ║"
        echo "║                                                               ║"
        echo "║  4) Query / recall                                            ║"
        echo "║     Semantic search across all stored documents.              ║"
        echo "║     Returns the most relevant chunks for a natural-language   ║"
        echo "║     query, ranked by similarity.                              ║"
        echo "║                                                               ║"
        echo "║  5) Delete (filtered)                                         ║"
        echo "║     Remove documents matching specific filters (project,      ║"
        echo "║     doc type, specificity). Shows matches before confirming.  ║"
        echo "║                                                               ║"
        echo "║  6) Clear all                                                 ║"
        echo "║     Wipe the entire second brain database. Use with care.     ║"
        echo "║                                                               ║"
        echo "║  7) Setup database                                            ║"
        echo "║     Create the schema, table, and vector index. Safe to       ║"
        echo "║     re-run — uses IF NOT EXISTS for all objects.              ║"
        echo "║                                                               ║"
        echo "║  q) Quit                                                      ║"
        echo "║                                                               ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo
        read -rp "Choice: " choice

        case "$choice" in
            1) do_list             ;;
            2) do_ingest_pipeline  ;;
            3) do_ingest           ;;
            4) do_recall           ;;
            5) do_delete           ;;
            6) do_clear_all        ;;
            7) do_setup            ;;
            q|Q) echo "Bye."; exit 0 ;;
            *) echo "Invalid choice."; sleep 1 ;;
        esac
    done
}

main_menu
