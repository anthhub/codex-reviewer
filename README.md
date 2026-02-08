# Codex Reviewer - Claude Code Plugin Marketplace

Dual AI cross-validation: Codex (GPT) reviews Claude Code output as a Senior Reviewer.

## Install

```
/plugin marketplace add anthhub/codex-reviewer
/plugin install codex-reviewer
```

### Prerequisites

- [Codex CLI](https://github.com/openai/codex) (`npm i -g @openai/codex`)
- `jq` (`brew install jq`)

### Verify

```
/cx-check
```

## Commands

| Command | Description |
|---------|-------------|
| `/cx` | Cross-review with Codex (supports semantic focus) |
| `/cx --quick` | Quick review mode |
| `/cx check security` | Focused review on specific dimension |
| `/cx-check` | Check configuration and dependencies |
| `/cx-history` | View review history |
| `/cx-clear` | Clear review history |

## How It Works

1. `/cx` launches a **subagent** (isolated context, no overflow)
2. Subagent collects `git diff`, searches relevant code if semantic focus provided
3. Passes context via temp files to `codex-reviewer.sh`
4. Codex CLI reviews and returns structured result with score + verdict

## Auto-Invoke

With the `codex-review` skill, Claude **automatically** invokes Codex review for:
- Security-related changes
- 3+ files or 100+ lines modified
- Architecture refactoring
- Bug fixes or new core features

## Configuration

Optional `.claude/reviewer.json`:

```json
{
  "model": "gpt-5.2-codex",
  "timeout": 300,
  "scoreThreshold": 85,
  "lang": "en",
  "saveHistory": true,
  "bypassApproval": true
}
```

## License

MIT

## Author

[anthhub](https://github.com/anthhub)
