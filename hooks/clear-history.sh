#!/bin/bash
# clear-history.sh - Clear Codex review history
# Usage: /cx-clear [--all | --days N | session_id]

set -e

CWD="${CLAUDE_PROJECT_DIR:-.}"
HISTORY_DIR="$CWD/.claude/review-history"

# Parse arguments
CLEAR_MODE="interactive"
DAYS_TO_KEEP=""
SESSION_ID=""

while [ $# -gt 0 ]; do
  case $1 in
    --all|-a)
      CLEAR_MODE="all"
      shift
      ;;
    --days|-d)
      CLEAR_MODE="days"
      DAYS_TO_KEEP="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: /cx-clear [options]"
      echo ""
      echo "Options:"
      echo "  --all, -a         Clear all review history"
      echo "  --days N, -d N    Keep only last N days of history"
      echo "  <session_id>      Clear specific session history"
      echo "  --help, -h        Show this help"
      echo ""
      echo "Examples:"
      echo "  /cx-clear --all           Clear all history"
      echo "  /cx-clear --days 7        Keep only last 7 days"
      echo "  /cx-clear manual-1234     Clear specific session"
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      shift
      ;;
    *)
      CLEAR_MODE="session"
      SESSION_ID="$1"
      shift
      ;;
  esac
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧹 Codex Review History Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -d "$HISTORY_DIR" ]; then
  echo "📁 No review history found."
  exit 0
fi

# Calculate current usage
TOTAL_SIZE=$(du -sh "$HISTORY_DIR" 2>/dev/null | cut -f1 || echo "0")
SESSION_COUNT=$(find "$HISTORY_DIR" -maxdepth 1 -type d -name "session_*" 2>/dev/null | wc -l | tr -d ' ')
FILE_COUNT=$(find "$HISTORY_DIR" -type f -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "📊 Current Status:"
echo "   Sessions: $SESSION_COUNT"
echo "   Files: $FILE_COUNT"
echo "   Size: $TOTAL_SIZE"
echo ""

case "$CLEAR_MODE" in
  all)
    echo "🗑️  Clearing ALL review history..."
    rm -rf "$HISTORY_DIR"
    mkdir -p "$HISTORY_DIR"
    echo "✅ All history cleared."
    ;;

  days)
    if [ -z "$DAYS_TO_KEEP" ] || ! [[ "$DAYS_TO_KEEP" =~ ^[0-9]+$ ]]; then
      echo "❌ Invalid days parameter. Usage: /cx-clear --days N"
      exit 1
    fi

    echo "🗑️  Removing history older than $DAYS_TO_KEEP days..."
    DELETED=0

    find "$HISTORY_DIR" -maxdepth 1 -type d -name "session_*" -mtime +"$DAYS_TO_KEEP" | while read -r dir; do
      rm -rf "$dir"
      DELETED=$((DELETED + 1))
    done

    # Also clean up old temp files
    find "${TMPDIR:-/tmp}" -maxdepth 1 -name "codex-reviewer-*" -type d -mtime +"$DAYS_TO_KEEP" -exec rm -rf {} \; 2>/dev/null || true

    echo "✅ Old history cleaned up."
    ;;

  session)
    if [ -z "$SESSION_ID" ]; then
      echo "❌ Please specify a session ID."
      exit 1
    fi

    SESSION_DIR="$HISTORY_DIR/session_$SESSION_ID"
    if [ -d "$SESSION_DIR" ]; then
      echo "🗑️  Clearing session: $SESSION_ID..."
      rm -rf "$SESSION_DIR"
      echo "✅ Session $SESSION_ID cleared."
    else
      echo "❌ Session not found: $SESSION_ID"
      echo ""
      echo "Available sessions:"
      ls -1 "$HISTORY_DIR" 2>/dev/null | grep "^session_" | sed 's/session_/  - /'
      exit 1
    fi
    ;;

  interactive)
    echo "Available options:"
    echo "  /cx-clear --all         Clear all history"
    echo "  /cx-clear --days 7      Keep only last 7 days"
    echo ""
    echo "Recent sessions:"
    ls -lt "$HISTORY_DIR" 2>/dev/null | grep "^d" | head -5 | while read -r line; do
      dir=$(echo "$line" | awk '{print $NF}')
      date=$(echo "$line" | awk '{print $6, $7, $8}')
      echo "  - $dir ($date)"
    done
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
