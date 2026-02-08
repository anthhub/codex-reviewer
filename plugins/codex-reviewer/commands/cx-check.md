---
description: Check Codex reviewer configuration and status
allowed-tools: Bash
---

# Codex Reviewer Health Check

Execute health check to verify configuration and dependencies:

!bash SCRIPT="$(find ~/.claude/plugins -name 'check-health.sh' -path '*/codex-reviewer/*' 2>/dev/null | head -1)"; [ -z "$SCRIPT" ] && SCRIPT="$CLAUDE_PROJECT_DIR/.claude/plugins/codex-reviewer/check-health.sh"; bash "$SCRIPT" $ARGUMENTS
