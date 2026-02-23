#!/bin/bash

# notify-ia-docs-read.sh — PostToolUse:Read hook
# 1. Shows a systemMessage notification when an IA-docs.md file is read
# 2. Tracks the read in a session state file (used by enforce-ia-docs.sh)
#
# State file: /tmp/claude-ia-docs-<session_id>
#   Shared with enforce-ia-docs.sh — when Claude explicitly reads a doc file,
#   we register it here so the enforce hook won't re-inject it.

# --- Load config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CONFIG_FILE="$PROJECT_DIR/ia-docs.config"

DOC_FILENAME="IA-docs.md"

if [[ -f "$CONFIG_FILE" ]]; then
  while IFS='=' read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    case "$key" in
      DOC_FILENAME) DOC_FILENAME="$value" ;;
    esac
  done < "$CONFIG_FILE"
fi

# Read full stdin
hook_input=$(cat)

filepath=$(echo "$hook_input" | jq -r '.tool_input.file_path // empty')

if [[ -z "$filepath" ]]; then
  exit 0
fi

if [[ "$filepath" == *"$DOC_FILENAME" ]]; then
  # --- Resolve session_id ---
  session_id=$(echo "$hook_input" | jq -r '.session_id // empty')

  if [[ -z "$session_id" ]]; then
    transcript=$(echo "$hook_input" | jq -r '.transcript_path // empty')
    if [[ -n "$transcript" ]]; then
      session_id=$(basename "$transcript" .jsonl)
    fi
  fi

  # --- Track in session state file ---
  if [[ -n "$session_id" ]]; then
    state_file="/tmp/claude-ia-docs-${session_id}"

    # Extract relative path from project root
    rel_path="${filepath#$PROJECT_DIR/}"
    if [[ "$rel_path" != "$filepath" ]]; then
      if ! grep -qF "$rel_path" "$state_file" 2>/dev/null; then
        echo "$rel_path" >> "$state_file"
      fi
    fi
  fi

  # --- Show notification ---
  display_path="${filepath#$PROJECT_DIR/}"
  if [[ "$display_path" == "$filepath" ]]; then
    display_path="$(basename "$(dirname "$filepath")")/$DOC_FILENAME"
  fi

  jq -n --arg msg "IA-DOC READ -- ${display_path}" \
    '{systemMessage: $msg}'
fi

exit 0
