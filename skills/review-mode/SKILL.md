---
name: review-mode
description: Enable Codex cross-validation mode
user-invocable: true
---

# Codex Cross-Validation Mode

Dual AI cross-validation mode is now enabled. In this mode:

## Workflow

1. **You (Claude)** complete solution design or code writing
2. **Codex (GPT-4)** automatically reviews your output
3. If Codex finds issues, you receive feedback and continue optimizing
4. Loop continues until both parties agree the task is complete

## Review Criteria

Codex checks the following aspects:
- Solution completeness
- Code quality
- Potential risks
- Edge cases
- Performance concerns
- Security issues

## Notes

- Maximum iterations: 5 (configurable)
- Each iteration Codex provides a score and specific feedback
- Score >= 85 with no critical issues required to pass

## Configuration

Configure via environment variables:
- `REVIEWER_ENABLED=true|false` - Enable/disable review
- `REVIEWER_MAX_ITERATIONS=5` - Maximum iterations
- `REVIEWER_SCORE_THRESHOLD=85` - Pass threshold
- `REVIEWER_MODEL=gpt-5.2-codex` - Model to use

Or via `.claude/reviewer.json` config file:

```json
{
  "enabled": true,
  "model": "gpt-5.2-codex",
  "maxIterations": 5,
  "scoreThreshold": 85,
  "saveHistory": true,
  "timeout": 300,
  "bypassApproval": true,
  "contextLines": 50
}
```

Now, please continue with your task. Codex will automatically review when you're done.
