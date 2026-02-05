# Codex Review History

View past code review results.

```bash
echo "📜 Codex Review History"
echo ""
if [ -d ".claude/review-history" ]; then
  ls -la .claude/review-history/ 2>/dev/null | tail -10
  echo ""
  echo "Recent reviews:"
  for f in .claude/review-history/*/iteration_*.md; do
    if [ -f "$f" ]; then
      echo "---"
      echo "📄 $f"
      head -20 "$f"
    fi
  done 2>/dev/null | tail -50
else
  echo "No review history found."
  echo "Run /cx to create your first review."
fi
```
