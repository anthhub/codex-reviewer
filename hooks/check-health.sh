#!/bin/bash
# check-health.sh - Check Codex reviewer configuration and dependencies

set -e

CWD="${CLAUDE_PROJECT_DIR:-.}"
CONFIG_FILE="$CWD/.claude/reviewer.json"
HISTORY_DIR="$CWD/.claude/review-history"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Codex Reviewer Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ISSUES=0

# 1. Check Codex CLI
echo "## Dependencies"
echo ""

if command -v codex > /dev/null 2>&1; then
  CODEX_VERSION=$(codex --version 2>&1 | head -1 || echo "unknown")
  echo "✅ Codex CLI: Installed ($CODEX_VERSION)"
else
  echo "❌ Codex CLI: NOT INSTALLED"
  echo "   Install with: npm i -g @openai/codex"
  ISSUES=$((ISSUES + 1))
fi

if command -v jq > /dev/null 2>&1; then
  echo "✅ jq: Installed"
else
  echo "❌ jq: NOT INSTALLED (required for config parsing)"
  echo "   Install with: brew install jq"
  ISSUES=$((ISSUES + 1))
fi

if command -v git > /dev/null 2>&1; then
  echo "✅ git: Installed"
else
  echo "⚠️  git: NOT INSTALLED (optional, needed for diff reviews)"
fi

echo ""

# 2. Check configuration
echo "## Configuration"
echo ""

if [ -f "$CONFIG_FILE" ]; then
  echo "✅ Config file: $CONFIG_FILE"

  # Validate JSON
  if jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "✅ JSON syntax: Valid"

    # Show current settings
    echo ""
    echo "Current settings:"
    echo "| Setting | Value |"
    echo "|---------|-------|"

    MODEL=$(jq -r '.model // "gpt-5.2-codex"' "$CONFIG_FILE")
    TIMEOUT=$(jq -r '.timeout // 300' "$CONFIG_FILE")
    THRESHOLD=$(jq -r '.scoreThreshold // 85' "$CONFIG_FILE")
    LANG=$(jq -r '.lang // "en"' "$CONFIG_FILE")
    HISTORY=$(jq -r '.saveHistory // true' "$CONFIG_FILE")

    echo "| model | \`$MODEL\` |"
    echo "| timeout | ${TIMEOUT}s |"
    echo "| scoreThreshold | $THRESHOLD |"
    echo "| lang | $LANG |"
    echo "| saveHistory | $HISTORY |"
  else
    echo "❌ JSON syntax: INVALID"
    echo "   Please fix the JSON syntax in $CONFIG_FILE"
    ISSUES=$((ISSUES + 1))
  fi
else
  echo "⚠️  Config file: Not found (using defaults)"
  echo "   Create $CONFIG_FILE to customize settings"
  echo ""
  echo "Default settings:"
  echo "| Setting | Value |"
  echo "|---------|-------|"
  echo "| model | \`gpt-5.2-codex\` |"
  echo "| timeout | 300s |"
  echo "| scoreThreshold | 85 |"
  echo "| lang | en |"
  echo "| saveHistory | true |"
fi

echo ""

# 3. Check Git repository
echo "## Git Repository"
echo ""

if [ -d "$CWD/.git" ]; then
  echo "✅ Git repository: Found"

  # Check for uncommitted changes
  CHANGES=$(cd "$CWD" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$CHANGES" -gt 0 ]; then
    echo "📝 Uncommitted changes: $CHANGES files"
  else
    echo "📝 Uncommitted changes: None"
  fi
else
  echo "⚠️  Git repository: Not found"
  echo "   Some review features require a git repository"
fi

echo ""

# 4. Check history
echo "## Review History"
echo ""

if [ -d "$HISTORY_DIR" ]; then
  SESSION_COUNT=$(find "$HISTORY_DIR" -maxdepth 1 -type d -name "session_*" 2>/dev/null | wc -l | tr -d ' ')
  TOTAL_SIZE=$(du -sh "$HISTORY_DIR" 2>/dev/null | cut -f1 || echo "0")

  echo "📁 History directory: $HISTORY_DIR"
  echo "📊 Sessions: $SESSION_COUNT"
  echo "💾 Size: $TOTAL_SIZE"

  # Warn if history is getting large
  SIZE_KB=$(du -sk "$HISTORY_DIR" 2>/dev/null | cut -f1 || echo "0")
  if [ "$SIZE_KB" -gt 10240 ]; then
    echo ""
    echo "⚠️  History is getting large (>10MB)"
    echo "   Consider running: /cx-clear --days 30"
  fi
else
  echo "📁 History directory: Not created yet"
fi

echo ""

# 5. Check temp directory
echo "## Temp Directory"
echo ""

SECURE_TEMP="${TMPDIR:-/tmp}/codex-reviewer-$(id -u)"
if [ -d "$SECURE_TEMP" ]; then
  PERMS=$(stat -f "%OLp" "$SECURE_TEMP" 2>/dev/null || stat -c "%a" "$SECURE_TEMP" 2>/dev/null || echo "unknown")
  echo "📁 Secure temp: $SECURE_TEMP"
  echo "🔒 Permissions: $PERMS"

  if [ "$PERMS" = "700" ]; then
    echo "✅ Permissions: Secure (owner-only)"
  else
    echo "⚠️  Permissions: Consider running 'chmod 700 $SECURE_TEMP'"
  fi
else
  echo "📁 Secure temp: Will be created on first run"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$ISSUES" -gt 0 ]; then
  echo "❌ Found $ISSUES issue(s) that need attention"
  exit 1
else
  echo "✅ All checks passed!"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
