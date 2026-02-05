#!/bin/bash
# manual-review.sh - Manually trigger Codex review
# Supports: /cx [file] [--quick] [--commit <hash>] [--staged]

set -e

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CWD="${CLAUDE_PROJECT_DIR:-.}"

# Security: Validate file path (no directory traversal)
validate_path() {
  local path="$1"
  # Check for directory traversal attempts
  if [[ "$path" == *".."* ]]; then
    echo "❌ Security error: Path contains '..' (directory traversal forbidden)" >&2
    exit 1
  fi
  # Check for absolute paths
  if [[ "$path" == /* ]]; then
    echo "❌ Security error: Please use relative paths" >&2
    exit 1
  fi
}

# Validate commit hash format
validate_commit() {
  local hash="$1"
  # Allow HEAD, HEAD~N, branch names, and hex hashes
  if [[ ! "$hash" =~ ^(HEAD(~[0-9]+)?|[a-zA-Z0-9_/-]+|[0-9a-f]{4,40})$ ]]; then
    echo "❌ Invalid commit reference: $hash" >&2
    exit 1
  fi
}

# Parse arguments
FILE_PATH=""
QUICK_MODE=false
COMMIT_HASH=""
CUSTOM_CONTEXT=""
STAGED_ONLY=false

while [ $# -gt 0 ]; do
  case $1 in
    --quick|-q)
      QUICK_MODE=true
      shift
      ;;
    --commit|-c)
      COMMIT_HASH="$2"
      validate_commit "$COMMIT_HASH"
      shift 2
      ;;
    --staged|-s)
      STAGED_ONLY=true
      shift
      ;;
    --context)
      CUSTOM_CONTEXT="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: /cx [file] [options]"
      echo ""
      echo "Options:"
      echo "  [file]           Review specific file only"
      echo "  --quick, -q      Quick review (shorter prompt, faster)"
      echo "  --staged, -s     Review only staged changes (git add)"
      echo "  --commit, -c     Review specific commit"
      echo "  --context        Custom context string"
      echo "  --help, -h       Show this help"
      echo ""
      echo "Examples:"
      echo "  /cx                    Review all uncommitted changes"
      echo "  /cx src/app.ts         Review specific file"
      echo "  /cx --quick            Quick review mode"
      echo "  /cx --staged           Review staged changes only"
      echo "  /cx -c HEAD~1          Review last commit"
      echo ""
      echo "Related commands:"
      echo "  /cx-history            View review history"
      echo "  /cx-clear              Clear review history"
      echo "  /cx-check              Check configuration"
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      shift
      ;;
    *)
      FILE_PATH="$1"
      validate_path "$FILE_PATH"
      shift
      ;;
  esac
done

# Generate session ID
SESSION_ID="manual-$(date +%s)"

# Get changes based on mode
CHANGES=""
CONTEXT=""

# Collect review scope info for Claude Code
REVIEW_SCOPE=""
CHANGED_FILES_LIST=""

echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "🔍 Codex Reviewer - Code Review" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2

if [ -n "$FILE_PATH" ]; then
  # Review specific file
  REVIEW_SCOPE="Single File Review"
  echo "📄 Target: $FILE_PATH" >&2

  if [ -f "$CWD/$FILE_PATH" ]; then
    FILE_LINES=$(wc -l < "$CWD/$FILE_PATH" | tr -d ' ')
    echo "   Lines: $FILE_LINES" >&2
    CHANGED_FILES_LIST="$FILE_PATH"

    # Get file content (limit to 500 lines)
    CHANGES=$(head -500 "$CWD/$FILE_PATH")
    CONTEXT="User wants to review the file: $FILE_PATH"

    # Also get git diff for this file if available
    if [ -d "$CWD/.git" ]; then
      DIFF=$(cd "$CWD" && git diff HEAD -- "$FILE_PATH" 2>/dev/null | head -100)
      if [ -n "$DIFF" ]; then
        DIFF_LINES=$(echo "$DIFF" | grep -c "^[+-]" 2>/dev/null || echo "0")
        echo "   Changed lines: ~$DIFF_LINES" >&2
        CHANGES="$CHANGES

--- Git Diff ---
$DIFF"
      fi
    fi
  else
    echo "❌ File not found: $FILE_PATH" >&2
    exit 1
  fi

elif [ -n "$COMMIT_HASH" ]; then
  # Review specific commit
  REVIEW_SCOPE="Commit Review"
  echo "📦 Target: Commit $COMMIT_HASH" >&2

  if [ -d "$CWD/.git" ]; then
    # Verify commit exists
    if ! cd "$CWD" && git rev-parse --verify "$COMMIT_HASH" >/dev/null 2>&1; then
      echo "❌ Commit not found: $COMMIT_HASH" >&2
      echo "   Please verify the commit hash is correct" >&2
      exit 1
    fi

    COMMIT_MSG=$(cd "$CWD" && git log -1 --format="%s" "$COMMIT_HASH" 2>/dev/null || echo "Unknown")
    COMMIT_FILES=$(cd "$CWD" && git show --name-only --format="" "$COMMIT_HASH" 2>/dev/null | head -10)
    COMMIT_FILE_COUNT=$(echo "$COMMIT_FILES" | wc -l | tr -d ' ')

    echo "   Message: $COMMIT_MSG" >&2
    echo "   Files: $COMMIT_FILE_COUNT" >&2
    CHANGED_FILES_LIST="$COMMIT_FILES"

    CONTEXT=$(cd "$CWD" && git log -1 --format="Commit: %h%nAuthor: %an%nDate: %ad%nMessage: %s" "$COMMIT_HASH" 2>/dev/null || echo "Invalid commit")
    CHANGES=$(cd "$CWD" && git show --stat -p "$COMMIT_HASH" 2>/dev/null | head -300 || echo "Cannot get commit diff")
  else
    echo "❌ Not a Git repository" >&2
    exit 1
  fi

elif [ "$STAGED_ONLY" = true ]; then
  # Review only staged changes
  REVIEW_SCOPE="Staged Changes Review"
  echo "📦 Target: Staged changes (git add)" >&2

  if [ -d "$CWD/.git" ]; then
    CHANGED_FILES_LIST=$(cd "$CWD" && git diff --cached --name-only 2>/dev/null)
    CHANGED_FILES=$(echo "$CHANGED_FILES_LIST" | grep -c "." 2>/dev/null || echo "0")

    if [ "$CHANGED_FILES" -eq 0 ] || [ -z "$CHANGED_FILES_LIST" ]; then
      echo "❌ No staged changes" >&2
      echo "   Please use 'git add' to stage files first" >&2
      exit 1
    fi

    echo "   Staged files: $CHANGED_FILES" >&2

    CHANGES=$(cd "$CWD" && git diff --cached --stat -p 2>/dev/null | head -300)
    CONTEXT="Reviewing staged changes before commit"
  else
    echo "❌ Not a Git repository" >&2
    exit 1
  fi

else
  # Review all uncommitted changes
  REVIEW_SCOPE="Uncommitted Changes Review"
  echo "📝 Target: All uncommitted changes" >&2

  if [ -d "$CWD/.git" ]; then
    # Get changed files (both staged and unstaged)
    CHANGED_FILES_LIST=$(cd "$CWD" && git diff --name-only HEAD 2>/dev/null)
    CHANGED_FILES=$(echo "$CHANGED_FILES_LIST" | grep -c "." 2>/dev/null || echo "0")

    if [ -z "$CHANGED_FILES_LIST" ]; then
      CHANGED_FILES=0
    fi

    # Check if there are any changes to review
    if [ "$CHANGED_FILES" -eq 0 ]; then
      echo "" >&2
      echo "✅ No uncommitted changes to review" >&2
      echo "" >&2
      echo "Try:" >&2
      echo "  /cx <file>       Review specific file" >&2
      echo "  /cx -c HEAD~1    Review last commit" >&2
      echo "  /cx --staged     Review staged changes" >&2
      exit 0
    fi

    echo "   Changed files: $CHANGED_FILES" >&2

    if [ "$CHANGED_FILES" -gt 0 ]; then
      echo "   Files:" >&2
      echo "$CHANGED_FILES_LIST" | head -5 | while read f; do
        [ -n "$f" ] && echo "     - $f" >&2
      done
      if [ "$CHANGED_FILES" -gt 5 ]; then
        echo "     ... and $((CHANGED_FILES - 5)) more files" >&2
      fi
    fi

    # Limit context for large diffs
    if [ "$CHANGED_FILES" -gt 5 ]; then
      echo "   ⚠️ Large diff, extracting top 3 files..." >&2
      CHANGES=$(cd "$CWD" && git diff --stat HEAD 2>/dev/null | head -50)
      CHANGES="$CHANGES

--- Top 3 files by changes ---"
      # Get top 3 most changed files
      TOP_FILES=$(cd "$CWD" && git diff --numstat HEAD 2>/dev/null | sort -k1 -rn | head -3 | awk '{print $3}')
      for f in $TOP_FILES; do
        CHANGES="$CHANGES

=== $f ===
$(cd "$CWD" && git diff HEAD -- "$f" 2>/dev/null | head -100)"
      done
    else
      CHANGES=$(cd "$CWD" && git diff --stat -p HEAD 2>/dev/null | head -300 || echo "No changes")
    fi

    CONTEXT=$(cd "$CWD" && git log --oneline -5 2>/dev/null || echo "No commit history")
  else
    echo "" >&2
    echo "⚠️  Not a Git repository" >&2
    echo "" >&2
    echo "Try:" >&2
    echo "  /cx <file>     Review specific file content" >&2
    exit 1
  fi
fi

# Use custom context if provided
if [ -n "$CUSTOM_CONTEXT" ]; then
  CONTEXT="$CUSTOM_CONTEXT"
fi

# Quick mode: shorter prompt
QUICK_FLAG=""
if [ "$QUICK_MODE" = true ]; then
  echo "⚡ Mode: Quick review" >&2
  QUICK_FLAG="--quick"
else
  echo "📋 Mode: Full review" >&2
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2

# Output scope summary for Claude Code (to stdout so it's visible in conversation)
echo ""
echo "## 📋 Codex Review Scope"
echo ""
echo "| Item | Value |"
echo "|------|-------|"
echo "| Review Type | $REVIEW_SCOPE |"
if [ -n "$FILE_PATH" ]; then
  echo "| Target File | \`$FILE_PATH\` |"
elif [ -n "$COMMIT_HASH" ]; then
  echo "| Target Commit | \`$COMMIT_HASH\` |"
elif [ "$STAGED_ONLY" = true ]; then
  echo "| Staged Files | $CHANGED_FILES |"
else
  echo "| Changed Files | $CHANGED_FILES |"
fi
if [ "$QUICK_MODE" = true ]; then
  echo "| Review Mode | ⚡ Quick |"
else
  echo "| Review Mode | 📋 Full |"
fi
echo ""

if [ -n "$CHANGED_FILES_LIST" ] && [ "$CHANGED_FILES_LIST" != "0" ]; then
  echo "**Files:**"
  echo '```'
  echo "$CHANGED_FILES_LIST" | head -10
  if [ "$(echo "$CHANGED_FILES_LIST" | wc -l)" -gt 10 ]; then
    echo "... (more files omitted)"
  fi
  echo '```'
  echo ""
fi

echo "---"
echo ""

# Call review script
"$PLUGIN_DIR/hooks/codex-reviewer.sh" \
  --context "$CONTEXT" \
  --changes "$CHANGES" \
  --iteration 0 \
  --session-id "$SESSION_ID" \
  --cwd "$CWD" \
  $QUICK_FLAG
