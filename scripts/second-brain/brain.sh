#!/usr/bin/env bash
#
# brain.sh - Menu-driven interface for second brain management
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON=python3

# ── Helpers ───────────────────────────────────────────────────────────────────

run_py() { "$PYTHON" "$SCRIPT_DIR/$1" "${@:2}"; }

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

do_ingest() {
    echo
    echo "=== Ingest Documents ==="
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
        echo "║  2) Ingest documents                                          ║"
        echo "║     Load markdown files from a directory into the database.   ║"
        echo "║     Replaces existing project data by default.                ║"
        echo "║                                                               ║"
        echo "║  3) Query / recall                                            ║"
        echo "║     Semantic search across all stored documents.              ║"
        echo "║     Returns the most relevant chunks for a natural-language   ║"
        echo "║     query, ranked by similarity.                              ║"
        echo "║                                                               ║"
        echo "║  4) Delete (filtered)                                         ║"
        echo "║     Remove documents matching specific filters (project,      ║"
        echo "║     doc type, specificity). Shows matches before confirming.  ║"
        echo "║                                                               ║"
        echo "║  5) Clear all                                                 ║"
        echo "║     Wipe the entire second brain database. Use with care.     ║"
        echo "║                                                               ║"
        echo "║  6) Setup database                                            ║"
        echo "║     Create the schema, table, and vector index. Safe to       ║"
        echo "║     re-run — uses IF NOT EXISTS for all objects.              ║"
        echo "║                                                               ║"
        echo "║  q) Quit                                                      ║"
        echo "║                                                               ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo
        read -rp "Choice: " choice

        case "$choice" in
            1) do_list      ;;
            2) do_ingest    ;;
            3) do_recall    ;;
            4) do_delete    ;;
            5) do_clear_all ;;
            6) do_setup     ;;
            q|Q) echo "Bye."; exit 0 ;;
            *) echo "Invalid choice."; sleep 1 ;;
        esac
    done
}

main_menu
