#!/bin/bash
#
# Uninstall Claude Code dotfiles by removing symlinks from ~/.claude
#
# Only removes symlinks that point back to this repo. Non-symlinked files
# (e.g., from a --copy install) are left untouched with a warning.
#
# Safe by default:
#   - Only removes symlinks pointing to this repo
#   - Warns about non-symlink files it cannot remove
#   - Does not remove ~/.claude itself or user files like .env
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.claude"

removed=0
skipped=0

remove_if_ours() {
    local target="$1"

    if [[ ! -e "$target" && ! -L "$target" ]]; then
        return
    fi

    if [[ -L "$target" ]]; then
        local link_dest
        link_dest="$(readlink -f "$target")"
        if [[ "$link_dest" == "$SCRIPT_DIR"* ]]; then
            rm "$target"
            echo "  removed: $target"
            removed=$((removed + 1))
        else
            echo "  skip (symlink to elsewhere): $target -> $link_dest"
            skipped=$((skipped + 1))
        fi
    else
        echo "  skip (not a symlink, may be from --copy install): $target"
        skipped=$((skipped + 1))
    fi
}

echo "Claude Code Dotfiles Uninstaller"
echo "================================="
echo "Source: $SCRIPT_DIR"
echo "Target: $TARGET_DIR"
echo ""

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Nothing to uninstall — $TARGET_DIR does not exist."
    exit 0
fi

# --- Top-level files ---
echo "Checking top-level files..."
remove_if_ours "$TARGET_DIR/CLAUDE.md"
remove_if_ours "$TARGET_DIR/settings.json"
remove_if_ours "$TARGET_DIR/.env.example"

# --- Slash commands ---
echo ""
echo "Checking slash commands..."
for cmd in "$SCRIPT_DIR"/commands/*.md; do
    name="$(basename "$cmd")"
    remove_if_ours "$TARGET_DIR/commands/$name"
done
# Remove commands dir if empty
rmdir "$TARGET_DIR/commands" 2>/dev/null && echo "  removed empty: $TARGET_DIR/commands" || true

# --- Skills ---
echo ""
echo "Checking skills..."
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    name="$(basename "$skill_dir")"
    remove_if_ours "$TARGET_DIR/skills/$name"
done
rmdir "$TARGET_DIR/skills" 2>/dev/null && echo "  removed empty: $TARGET_DIR/skills" || true

# --- Rules ---
echo ""
echo "Checking rules..."
for rule in "$SCRIPT_DIR"/rules/*.md; do
    [[ -e "$rule" ]] || continue
    name="$(basename "$rule")"
    remove_if_ours "$TARGET_DIR/rules/$name"
done
rmdir "$TARGET_DIR/rules" 2>/dev/null && echo "  removed empty: $TARGET_DIR/rules" || true

# --- Scripts (top-level files) ---
echo ""
echo "Checking scripts..."
for script in "$SCRIPT_DIR"/scripts/*.sh; do
    [[ -e "$script" ]] || continue
    name="$(basename "$script")"
    remove_if_ours "$TARGET_DIR/scripts/$name"
done

# --- Script subdirectories ---
for script_sub in "$SCRIPT_DIR"/scripts/*/; do
    [[ -d "$script_sub" ]] || continue
    name="$(basename "$script_sub")"
    [[ "$name" == "review-logs" ]] && continue
    remove_if_ours "$TARGET_DIR/scripts/$name"
done
rmdir "$TARGET_DIR/scripts" 2>/dev/null && echo "  removed empty: $TARGET_DIR/scripts" || true

# --- Summary ---
echo ""
echo "================================="
echo "Done. Removed $removed item(s)."
if [[ "$skipped" -gt 0 ]]; then
    echo "Skipped $skipped item(s) — not symlinks to this repo."
fi
echo ""
echo "User files preserved (not touched):"
echo "  - ~/.claude/.env"
echo "  - ~/.claude/projects/"
echo "  - ~/.claude/backup-*/"
