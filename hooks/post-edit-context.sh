#!/bin/bash
# post-edit-context.sh - Records change context after tool use

set -e

INPUT=$(cat)

# Parse input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // "{}"')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Only process file editing related tools
case "$TOOL_NAME" in
  Edit|Write|Bash)
    ;;
  *)
    exit 0
    ;;
esac

# Configuration check
CONFIG_FILE="$CWD/.claude/reviewer.json"
ENABLED="${REVIEWER_ENABLED:-true}"

if [ -f "$CONFIG_FILE" ]; then
  ENABLED=$(jq -r '.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "$ENABLED")
fi

if [ "$ENABLED" != "true" ]; then
  exit 0
fi

# Save context to temp file
CONTEXT_FILE="/tmp/codex-review-$SESSION_ID.context"

# Append change record
{
  echo "---"
  echo "Tool: $TOOL_NAME"
  echo "Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Input: $(echo "$TOOL_INPUT" | head -c 500)"
  echo "---"
} >> "$CONTEXT_FILE"

# Limit context file size (keep last 100 lines)
if [ -f "$CONTEXT_FILE" ]; then
  tail -100 "$CONTEXT_FILE" > "$CONTEXT_FILE.tmp"
  mv "$CONTEXT_FILE.tmp" "$CONTEXT_FILE"
fi

exit 0
