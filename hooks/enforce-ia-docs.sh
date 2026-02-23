#!/bin/bash

# enforce-ia-docs.sh — PreToolUse hook for Edit|Write
# Injects IA-docs.md content as additionalContext when editing files in the source directory.
#
# Strategy: Instead of BLOCKING edits (exit 2) and hoping Claude reads docs,
# this hook INJECTS the required IA-docs.md content directly into the edit
# context. The edit always proceeds, and Claude always has the docs it needs.
#
# How it works:
#   1. Reads JSON from stdin, extracts file_path and session_id
#   2. If the file is NOT in the configured source directory → exit 0 (no-op)
#   3. Builds a list of required IA-docs.md: root + every existing
#      IA-docs.md in directories between root and the target file
#   4. Checks state file for docs already injected/read in this session
#   5. If all processed → exit 0 (no redundant injection)
#   6. If missing: reads their content, outputs as additionalContext (allow)
#
# Configuration (via ia-docs.config at project root):
#   SOURCE_DIR — the directory subtree to enforce (e.g., "src", "backend/src")
#   DOC_FILENAME — the filename to look for (default: "IA-docs.md")
#
# State file: /tmp/claude-ia-docs-<session_id>
#   Shared with notify-ia-docs-read.sh (tracks explicit reads too)

# --- Load config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CONFIG_FILE="$PROJECT_DIR/ia-docs.config"

# Defaults
SOURCE_DIR="src"
DOC_FILENAME="IA-docs.md"

if [[ -f "$CONFIG_FILE" ]]; then
  while IFS='=' read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    case "$key" in
      SOURCE_DIR) SOURCE_DIR="$value" ;;
      DOC_FILENAME) DOC_FILENAME="$value" ;;
    esac
  done < "$CONFIG_FILE"
fi

# Read full stdin
hook_input=$(cat)

filepath=$(echo "$hook_input" | jq -r '.tool_input.file_path // empty')
session_id=$(echo "$hook_input" | jq -r '.session_id // empty')

# Quick exit: no filepath or not in the source directory
if [[ -z "$filepath" ]] || [[ "$filepath" != *"$SOURCE_DIR/"* ]]; then
  exit 0
fi

# --- Resolve session_id with fallbacks ---
if [[ -z "$session_id" ]]; then
  transcript=$(echo "$hook_input" | jq -r '.transcript_path // empty')
  if [[ -n "$transcript" ]]; then
    session_id=$(basename "$transcript" .jsonl)
  fi
fi

# If no session_id, allow without injection (never block)
if [[ -z "$session_id" ]]; then
  exit 0
fi

state_file="/tmp/claude-ia-docs-${session_id}"

# --- Build list of required doc files ---
# Always include root-level doc if it exists
required=()
if [[ -f "$PROJECT_DIR/$DOC_FILENAME" ]]; then
  required+=("$DOC_FILENAME")
fi

# Include source-dir-level doc if it exists
if [[ -f "$PROJECT_DIR/$SOURCE_DIR/$DOC_FILENAME" ]]; then
  required+=("$SOURCE_DIR/$DOC_FILENAME")
fi

# Walk from target file's directory up toward SOURCE_DIR, collecting existing docs
rel_path="${filepath#*$SOURCE_DIR/}"
dir_path=$(dirname "$rel_path")

while [[ "$dir_path" != "." && -n "$dir_path" ]]; do
  doc_path="$SOURCE_DIR/${dir_path}/$DOC_FILENAME"
  if [[ -f "$PROJECT_DIR/$doc_path" ]]; then
    required+=("$doc_path")
  fi
  dir_path=$(dirname "$dir_path")
done

# No docs found at all → nothing to inject
if [[ ${#required[@]} -eq 0 ]]; then
  exit 0
fi

# --- Check state file for already-processed docs ---
missing=()
for doc in "${required[@]}"; do
  if ! grep -qF "$doc" "$state_file" 2>/dev/null; then
    missing+=("$doc")
  fi
done

# All already processed → allow without extra context
if [[ ${#missing[@]} -eq 0 ]]; then
  exit 0
fi

# --- Build content from missing docs ---
context=""
for doc in "${missing[@]}"; do
  full_path="$PROJECT_DIR/$doc"
  if [[ -f "$full_path" ]]; then
    file_content=$(cat "$full_path")
    context+="--- ${doc} ---"$'\n'"${file_content}"$'\n\n'
    echo "$doc" >> "$state_file"
  fi
done

if [[ -z "$context" ]]; then
  exit 0
fi

# --- Output hookSpecificOutput with additionalContext ---
full_context="--- IA-DOCS (hierarchy for your edit) ---"$'\n\n'"${context}"

jq -n --arg ctx "$full_context" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    additionalContext: $ctx
  }
}'

exit 0
