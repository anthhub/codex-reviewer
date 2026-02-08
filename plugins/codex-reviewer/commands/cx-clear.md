---
description: Clear Codex review history
allowed-tools: Bash
---

# Codex Review History Cleanup

Execute cleanup script to clear review history:

!bash SCRIPT="$(find ~/.claude/plugins -name 'clear-history.sh' -path '*/codex-reviewer/*' 2>/dev/null | head -1)"; [ -z "$SCRIPT" ] && SCRIPT="$CLAUDE_PROJECT_DIR/.claude/plugins/codex-reviewer/clear-history.sh"; bash "$SCRIPT" $ARGUMENTS
