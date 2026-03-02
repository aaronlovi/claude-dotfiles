#!/usr/bin/env bash
# Claude Code status line script
# Displays: user@host  cwd  model  context usage bar

user=$(whoami)
host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "localhost")

# Require jq
if ! command -v jq &>/dev/null; then
  printf '%s@%s  (jq not found)' "$user" "$host"
  exit 0
fi

# Read stdin; exit gracefully if empty
input=$(cat 2>/dev/null)
if [ -z "$input" ]; then
  printf '%s@%s' "$user" "$host"
  exit 0
fi

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
short_cwd="${cwd/#$HOME/\~}"

# Build context bar (10 blocks)
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  filled=$(( used_int / 10 ))
  empty=$(( 10 - filled ))
  bar=$(printf '%*s' "$filled" '' | tr ' ' '#')$(printf '%*s' "$empty" '' | tr ' ' '-')

  # Color: green < 70%, yellow 70-89%, red >= 90%
  if [ "$used_int" -ge 90 ]; then
    color=$'\033[31m'   # red
  elif [ "$used_int" -ge 70 ]; then
    color=$'\033[33m'   # yellow
  else
    color=$'\033[32m'   # green
  fi
  reset=$'\033[0m'
  ctx_part="${color}${bar} ${used_int}% used${reset}"
else
  ctx_part="no messages yet"
fi

printf $'\033[1m%s@%s\033[0m  \033[34m%s\033[0m  %s  %s' \
  "$user" "$host" "$short_cwd" "$model" "$ctx_part"
