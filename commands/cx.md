# Codex Review

Trigger a Codex code review.

## Usage

```
/cx                     Review all uncommitted changes
/cx <file>              Review specific file
/cx --quick             Quick review (faster, shorter)
/cx --commit HEAD~1     Review specific commit
/cx --help              Show help
```

$ARGUMENTS

```bash
".claude/plugins/codex-reviewer/hooks/manual-review.sh" $ARGUMENTS
```
