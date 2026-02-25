#!/bin/bash
#
# Iteratively review slash commands until no more changes are made.
# Convergence is detected by checksumming all command/skill files before
# and after each iteration.
#
# Logs capture DIFFS of actual file changes (not Claude's stdout, which
# is sparse in -p mode since tool use isn't echoed).
#

set -euo pipefail

COMMANDS_DIR="$HOME/.claude/commands"
SKILLS_DIR="$HOME/.claude/skills"
MAX_ITERATIONS=${1:-5}
LOG_DIR="$HOME/.claude/scripts/review-logs"

mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

PROMPT='Review all slash commands in ~/.claude/commands/ and all skills in ~/.claude/skills/ and fix issues you find.

## Review Dimensions

1. **Structural consistency**: Uniform section ordering (Purpose → Audience → Inputs → Process → Output Format → Error Handling → Next Step), heading conventions, and formatting across all commands and skills
2. **Completeness**: Every command has concrete Process steps, an Output Format with a copy-pasteable template, error/edge-case guidance, and a "Next step" that names exactly one pipeline successor
3. **Downstream compatibility**: Output format templates include ALL fields that downstream commands validate or consume (e.g., if /review-requirements checks for a Phase field, the upstream command template must emit it)
4. **Precision of instructions**: Replace vague directives ("consider", "think about", "ensure") with concrete, verifiable criteria an LLM can follow unambiguously
5. **Pipeline coherence**: Commands that feed into each other have compatible input/output contracts; cross-references use correct document filenames
6. **Appropriate information density**: Instructions should be dense enough for an LLM to act without guessing, but not so verbose that they dilute the signal. Remove redundant restatements; add specifics where missing.

## Rules

- Fix issues directly in the files — do not just report them.
- Do NOT fix nitpicks (minor wording preferences, stylistic variation that does not affect clarity). Focus on issues that would cause incorrect or suboptimal output.
- After all changes, output a summary table with columns: Severity (Major/Minor), File, Issue, Fix Applied.
- If you found and fixed zero issues, say exactly: "NO_CHANGES_FOUND"'

get_checksum() {
    find -L "$COMMANDS_DIR" "$SKILLS_DIR" -name "*.md" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | cut -d' ' -f1
}

snapshot_files() {
    local snap_dir="$1"
    mkdir -p "$snap_dir/commands" "$snap_dir/skills"
    cp -r "$COMMANDS_DIR"/. "$snap_dir/commands/" 2>/dev/null || true
    cp -r "$SKILLS_DIR"/. "$snap_dir/skills/" 2>/dev/null || true
}

echo "=== Slash Command Review Loop ==="
echo "Max iterations: $MAX_ITERATIONS"
echo "Log directory:  $LOG_DIR"
echo ""

iteration=0
total_changes=0

while [ "$iteration" -lt "$MAX_ITERATIONS" ]; do
    iteration=$((iteration + 1))
    log_file="$LOG_DIR/${TIMESTAMP}-iteration-${iteration}.md"

    echo "--- Iteration $iteration of $MAX_ITERATIONS ---"

    # Snapshot files before this iteration
    snap_before=$(mktemp -d)
    snapshot_files "$snap_before"
    before=$(get_checksum)

    # Run Claude in print mode (non-interactive)
    # stdout is sparse in -p mode (tool use not echoed), so we capture
    # Claude's text response separately and focus on diffs for the log.
    # Separate stderr so errors are visible; capture stdout for the log.
    claude_stderr=$(mktemp)
    claude_output=$(claude -p "$PROMPT" --allowedTools 'Read,Write,Edit,Glob,Grep,Task' 2>"$claude_stderr") || true
    if [ -s "$claude_stderr" ]; then
        echo "  [stderr] $(cat "$claude_stderr")"
    fi
    rm -f "$claude_stderr"

    after=$(get_checksum)

    # Build the log: Claude's response + diff of actual changes
    {
        echo "# Iteration $iteration — $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "## Claude Response"
        echo ""
        if [ -n "$claude_output" ]; then
            echo "$claude_output"
        else
            echo "(no text output)"
        fi
        echo ""
        echo "## File Diffs"
        echo ""

        # Diff commands
        cmd_diff=$(diff -ru "$snap_before/commands" "$COMMANDS_DIR" 2>/dev/null) || true
        skill_diff=$(diff -ru "$snap_before/skills" "$SKILLS_DIR" 2>/dev/null) || true

        if [ -n "$cmd_diff" ] || [ -n "$skill_diff" ]; then
            echo '```diff'
            [ -n "$cmd_diff" ] && echo "$cmd_diff"
            [ -n "$skill_diff" ] && echo "$skill_diff"
            echo '```'
        else
            echo "(no file changes)"
        fi
    } > "$log_file"

    # Clean up snapshot
    rm -rf "$snap_before"

    # Print Claude's response to terminal too
    if [ -n "$claude_output" ]; then
        echo "$claude_output"
    fi

    if [ "$before" = "$after" ]; then
        echo ""
        echo "=== Converged after $iteration iteration(s) — no file changes detected ==="
        break
    else
        total_changes=$((total_changes + 1))
        echo ""
        echo "=== Files changed in iteration $iteration — continuing ==="
        echo ""
    fi
done

if [ "$iteration" -ge "$MAX_ITERATIONS" ]; then
    echo ""
    echo "=== Reached max iterations ($MAX_ITERATIONS) without convergence ==="
fi

echo ""
echo "Summary: $total_changes iteration(s) produced changes out of $iteration total."
echo "Logs saved to: $LOG_DIR/${TIMESTAMP}-iteration-*.md"
