#!/bin/bash
# stop-review.sh - Triggers Codex review when Claude completes a response

set -e

# Helper function for streaming progress output
progress() {
  echo "[Codex Reviewer] $1" >&2
}

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INPUT=$(cat)

# Parse input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Prevent infinite loop
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# ==================== Load Configuration ====================

CONFIG_FILE="$CWD/.claude/reviewer.json"
ENABLED="${REVIEWER_ENABLED:-true}"
MAX_ITERATIONS="${REVIEWER_MAX_ITERATIONS:-5}"
CONTEXT_LINES="${REVIEWER_CONTEXT_LINES:-50}"
MODEL="${REVIEWER_MODEL:-gpt-5.2-codex}"
SCORE_THRESHOLD="${REVIEWER_SCORE_THRESHOLD:-85}"

if [ -f "$CONFIG_FILE" ]; then
  ENABLED=$(jq -r '.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "$ENABLED")
  MAX_ITERATIONS=$(jq -r '.maxIterations // 5' "$CONFIG_FILE" 2>/dev/null || echo "$MAX_ITERATIONS")
  CONTEXT_LINES=$(jq -r '.contextLines // 50' "$CONFIG_FILE" 2>/dev/null || echo "$CONTEXT_LINES")
  MODEL=$(jq -r '.model // "o3"' "$CONFIG_FILE" 2>/dev/null || echo "$MODEL")
  SCORE_THRESHOLD=$(jq -r '.scoreThreshold // 85' "$CONFIG_FILE" 2>/dev/null || echo "$SCORE_THRESHOLD")
fi

if [ "$ENABLED" != "true" ]; then
  exit 0
fi

# ==================== Iteration Control ====================

ITERATION_FILE="/tmp/codex-review-$SESSION_ID.iteration"
ITERATION=$(cat "$ITERATION_FILE" 2>/dev/null || echo "0")

if [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
  progress "⚠️  Max iterations ($MAX_ITERATIONS) reached, auto-passing"
  rm -f "$ITERATION_FILE"
  exit 0
fi

echo $((ITERATION + 1)) > "$ITERATION_FILE"

progress "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
progress "🔍 Starting Codex Review (Iteration $((ITERATION + 1))/$MAX_ITERATIONS)"
progress "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ==================== Extract Context ====================

progress "📋 Extracting conversation context..."

# Extract recent conversation from transcript (pure bash)
CONTEXT=""
if [ -f "$TRANSCRIPT_PATH" ]; then
  CONTEXT=$(tail -n "$CONTEXT_LINES" "$TRANSCRIPT_PATH" | \
    jq -rs 'map(select(.role) | "\(.role | ascii_upcase):\n\(.content | if type == "array" then map(select(.type == "text") | .text) | join("\n") else . end)\n---") | join("\n")' 2>/dev/null || echo "Cannot parse conversation history")
  progress "   ✓ Extracted $CONTEXT_LINES lines of context"
else
  progress "   ⚠️  No transcript found"
fi

# Get git diff
progress "📝 Checking code changes..."
CHANGES=""
if [ -d "$CWD/.git" ]; then
  CHANGES=$(cd "$CWD" && git diff --stat -p HEAD 2>/dev/null | head -200 || echo "No changes")
  CHANGE_COUNT=$(echo "$CHANGES" | grep -c "^[+-]" 2>/dev/null || echo "0")
  progress "   ✓ Found ~$CHANGE_COUNT lines changed"
else
  progress "   ⚠️  Not a git repository"
fi

# ==================== Call Codex Review ====================

progress "🤖 Calling Codex for review..."
progress "   Model: $MODEL"
progress "   Threshold: $SCORE_THRESHOLD/100"

REVIEW_RESULT=$("$PLUGIN_DIR/hooks/codex-reviewer.sh" \
  --context "$CONTEXT" \
  --changes "$CHANGES" \
  --iteration "$ITERATION" \
  --session-id "$SESSION_ID" \
  --cwd "$CWD")

# ==================== Parse Result ====================

VERDICT=$(echo "$REVIEW_RESULT" | jq -r '.verdict // "pass"')
SCORE=$(echo "$REVIEW_RESULT" | jq -r '.score // 0')
SUMMARY=$(echo "$REVIEW_RESULT" | jq -r '.summary // ""')
FEEDBACK=$(echo "$REVIEW_RESULT" | jq -r '.feedback // ""')
RISKS=$(echo "$REVIEW_RESULT" | jq -r 'if .risks then .risks | join("\n  - ") else "" end')
MISSING=$(echo "$REVIEW_RESULT" | jq -r 'if .missing then .missing | join("\n  - ") else "" end')
VULNERABILITIES=$(echo "$REVIEW_RESULT" | jq -r 'if .vulnerabilities then .vulnerabilities | join("\n  - ") else "" end')
SUGGESTIONS=$(echo "$REVIEW_RESULT" | jq -r 'if .suggestions then .suggestions | join("\n  - ") else "" end')
MUST_FIX=$(echo "$REVIEW_RESULT" | jq -r 'if .mustFix then .mustFix | join("\n  - ") else "" end')

# ==================== Output Result ====================

progress "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$VERDICT" = "pass" ]; then
  rm -f "$ITERATION_FILE"

  progress "✅ REVIEW PASSED!"
  progress "   Score: $SCORE/100"
  progress "   $SUMMARY"
  progress "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  progress "🎉 Dual AI verification complete!"

  echo ""
  echo "========================================"
  echo "  Codex Review PASSED (Iteration $((ITERATION + 1)))"
  echo "========================================"
  echo "  Score: $SCORE/100"
  echo "  Summary: $SUMMARY"
  echo "  Feedback: $FEEDBACK"
  echo "========================================"
  echo ""
  echo "Dual AI verification complete!"
  exit 0
else
  progress "❌ NEEDS WORK"
  progress "   Score: $SCORE/100 (threshold: $SCORE_THRESHOLD)"
  progress "   $SUMMARY"
  progress "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  progress "🔄 Claude will continue based on feedback..."

  # Build feedback message
  REVIEW_MSG="
========================================
  Codex Reviewer Feedback (Iteration $((ITERATION + 1))/$MAX_ITERATIONS)
========================================
  Current Score: $SCORE/100
  Summary: $SUMMARY
----------------------------------------
  Main Issues:
  $FEEDBACK
----------------------------------------
  Risks:
  - $RISKS
----------------------------------------
  Vulnerabilities:
  - $VULNERABILITIES
----------------------------------------
  Missing Items:
  - $MISSING
----------------------------------------
  Suggestions:
  - $SUGGESTIONS
----------------------------------------
  Must Fix:
  - $MUST_FIX
========================================

Please continue to optimize based on the feedback above until the review passes."

  jq -n --arg reason "$REVIEW_MSG" '{"decision": "block", "reason": $reason}'
  exit 0
fi
