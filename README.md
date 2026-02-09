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
| `/cx` | Cross-review with Codex (default score >= 80) |
| `/cx 90` | Review with custom score threshold |
| `/cx --quick` | Quick review mode |
| `/cx check security` | Focused review on specific dimension |
| `/cx 90 check security` | Custom score + focused review |
| `/cxx` | Advanced review (high reasoning effort, longer timeout) |
| `/cxx 95` | Advanced + custom score threshold |
| `/cxx check security` | Advanced + focused review |
| `/cx-check` | Check configuration and dependencies |
| `/cx-history` | View review history |
| `/cx-clear` | Clear review history |

## How It Works

1. `/cx` or `/cxx` launches a **subagent** (isolated context, no overflow)
2. Subagent collects evidence:
   - `git diff` and recent commit history
   - **Upstream callers** — who imports/depends on the changed code
   - **Downstream dependencies** — what the changed code depends on
   - **Related test files** — matched by filename and symbol references
   - **Test results, build status** — runs project tests and build automatically
3. Passes all context via temp files to `codex-reviewer.sh`
4. Codex CLI reviews with configurable reasoning effort and returns structured result with score + verdict
5. Review focuses on **core path stability** — upstream/downstream breakage is weighted highest

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
  "advancedTimeout": 600,
  "scoreThreshold": 80,
  "lang": "en",
  "saveHistory": true,
  "bypassApproval": true,
  "reasoningEffort": {
    "quick": "low",
    "standard": "medium",
    "advanced": "high"
  }
}
```

## License

MIT

## Author

[anthhub](https://github.com/anthhub)
