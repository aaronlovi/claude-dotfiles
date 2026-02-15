#!/bin/bash
#
# Install Claude Code dotfiles by symlinking into ~/.claude
#
# Usage: ./install.sh [--copy]
#
#   Default:  symlinks files (changes to repo are reflected immediately)
#   --copy:   copies files instead (standalone, no repo dependency)
#
# Safe by default:
#   - Backs up any existing file before overwriting
#   - Creates ~/.claude if it doesn't exist
#   - Skips files that are already correctly linked
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.claude"
BACKUP_DIR="$TARGET_DIR/backup-$(date +%Y%m%d-%H%M%S)"
MODE="symlink"

if [[ "${1:-}" == "--copy" ]]; then
    MODE="copy"
fi

backed_up=0

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        local rel="${target#$TARGET_DIR/}"
        local backup_path="$BACKUP_DIR/$rel"
        mkdir -p "$(dirname "$backup_path")"
        cp -a "$target" "$backup_path"
        backed_up=$((backed_up + 1))
    fi
}

install_file() {
    local src="$1"
    local dest="$2"

    # Skip if already correctly symlinked
    if [[ "$MODE" == "symlink" && -L "$dest" ]]; then
        local current
        current="$(readlink -f "$dest")"
        if [[ "$current" == "$(readlink -f "$src")" ]]; then
            echo "  skip (already linked): $dest"
            return
        fi
    fi

    backup_if_exists "$dest"
    mkdir -p "$(dirname "$dest")"

    if [[ "$MODE" == "symlink" ]]; then
        ln -sf "$src" "$dest"
        echo "  link: $dest -> $src"
    else
        cp -a "$src" "$dest"
        echo "  copy: $src -> $dest"
    fi
}

install_dir() {
    local src_dir="$1"
    local dest_dir="$2"

    # For symlink mode, link the whole directory
    if [[ "$MODE" == "symlink" ]]; then
        if [[ -L "$dest_dir" ]]; then
            local current
            current="$(readlink -f "$dest_dir")"
            if [[ "$current" == "$(readlink -f "$src_dir")" ]]; then
                echo "  skip (already linked): $dest_dir"
                return
            fi
        fi

        backup_if_exists "$dest_dir"
        # Remove existing directory/link so we can replace it
        rm -rf "$dest_dir"
        mkdir -p "$(dirname "$dest_dir")"
        ln -sf "$src_dir" "$dest_dir"
        echo "  link: $dest_dir -> $src_dir"
    else
        mkdir -p "$dest_dir"
        cp -a "$src_dir"/. "$dest_dir"/
        echo "  copy: $src_dir -> $dest_dir"
    fi
}

echo "Claude Code Dotfiles Installer"
echo "==============================="
echo "Mode:   $MODE"
echo "Source: $SCRIPT_DIR"
echo "Target: $TARGET_DIR"
echo ""

mkdir -p "$TARGET_DIR"

# --- Top-level files ---
echo "Installing top-level files..."
install_file "$SCRIPT_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
install_file "$SCRIPT_DIR/settings.json" "$TARGET_DIR/settings.json"

# --- Slash commands ---
echo ""
echo "Installing slash commands..."
mkdir -p "$TARGET_DIR/commands"
for cmd in "$SCRIPT_DIR"/commands/*.md; do
    name="$(basename "$cmd")"
    install_file "$cmd" "$TARGET_DIR/commands/$name"
done

# --- Skills ---
echo ""
echo "Installing skills..."
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    name="$(basename "$skill_dir")"
    install_dir "$SCRIPT_DIR/skills/$name" "$TARGET_DIR/skills/$name"
done

# --- Scripts ---
echo ""
echo "Installing scripts..."
mkdir -p "$TARGET_DIR/scripts"
for script in "$SCRIPT_DIR"/scripts/*.sh; do
    name="$(basename "$script")"
    install_file "$script" "$TARGET_DIR/scripts/$name"
done

# --- Summary ---
echo ""
echo "==============================="
echo "Done."
if [[ "$backed_up" -gt 0 ]]; then
    echo "Backed up $backed_up existing file(s) to: $BACKUP_DIR"
fi
echo ""
echo "Installed:"
echo "  - CLAUDE.md (global preferences)"
echo "  - settings.json (allowed tools + env)"
echo "  - $(ls "$SCRIPT_DIR"/commands/*.md | wc -l) slash commands"
echo "  - $(ls -d "$SCRIPT_DIR"/skills/*/ | wc -l) skills"
echo "  - $(ls "$SCRIPT_DIR"/scripts/*.sh | wc -l) script(s)"
