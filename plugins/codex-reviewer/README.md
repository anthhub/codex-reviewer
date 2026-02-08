# Codex Reviewer

A Claude Code plugin that enables dual AI cross-validation using Codex CLI as a Senior Reviewer.

## Features

- **Subagent Architecture**: All reviews run in isolated Task subagent, preventing main conversation context overflow
- **Semantic Review**: Pass natural language to focus Codex on specific concerns (e.g., `/cx check security`)
- **Dual AI Verification**: Claude Code generates solutions, Codex reviews them
- **Quick Mode**: `--quick` flag for faster, shorter reviews
- **Auto-Invoke**: Claude automatically triggers Codex review based on change scope and risk
- **Security Hardened**: Input sanitization, secure temp directories
- **History Tracking**: Saves review history for future reference

## Installation

### Prerequisites

- [Claude Code](https://claude.ai/code) CLI installed
- [Codex CLI](https://github.com/openai/codex) installed (`npm i -g @openai/codex`)
- `jq` for JSON parsing (`brew install jq`)

### Install via Marketplace (Recommended)

```
/plugin marketplace add anthhub/codex-reviewer
/plugin install codex-reviewer
```

### Verify Installation

```
/cx-check
```

## Usage

```bash
/cx                              # Review all uncommitted changes
/cx --quick                      # Quick review (faster)
/cx check auth security             # Focused review on auth security
/cx review error handling        # Focused review on error handling
/cx --quick check performance        # Quick focused review
```

All `/cx` calls launch a **subagent** that:
1. Gets `git diff` and recent commit history
2. If semantic text provided: searches relevant code files and documentation
3. Writes context to temp files and calls `codex-reviewer.sh`
4. Returns structured review result to main conversation

Support commands:

| Command | Description |
|---------|-------------|
| `/cx-history` | View review history |
| `/cx-clear` | Clear review history |
| `/cx-check` | Check configuration and dependencies |

## Auto-Invoke Behavior

With the `codex-review` skill installed, Claude will **automatically** invoke Codex cross-review when:

- Security-related changes (auth, permissions, keys, input validation)
- 3+ files modified or 100+ lines changed
- Architecture refactoring
- Bug fixes or new core features

See `skills/codex-review/SKILL.md` for the full auto-invoke strategy.

## Configuration

`.claude/reviewer.json`:

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

Environment variables: `REVIEWER_MODEL`, `REVIEWER_TIMEOUT`, `REVIEWER_SCORE_THRESHOLD`, `REVIEWER_LANG`.

## codex-reviewer.sh Parameters

| Parameter | Description |
|-----------|-------------|
| `--context-file <path>` | Read context from file (for subagent) |
| `--changes-file <path>` | Read changes from file (for subagent) |
| `--user-requirement <text>` | Semantic review focus (included in Codex prompt) |
| `--context <text>` | Inline context (for direct CLI use) |
| `--changes <text>` | Inline changes (for direct CLI use) |
| `--quick` | Quick review mode |
| `--session-id <id>` | Session identifier |
| `--cwd <dir>` | Working directory |

## File Structure

```
plugins/codex-reviewer/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── hooks/
│   ├── codex-reviewer.sh    # Core: builds prompt, calls Codex CLI
│   ├── check-health.sh      # Health check
│   ├── clear-history.sh     # History cleanup
│   └── hooks.json
├── commands/
│   ├── cx.md                # /cx command (subagent-based)
│   ├── cx-history.md        # /cx-history command
│   ├── cx-clear.md          # /cx-clear command
│   └── cx-check.md          # /cx-check command
├── skills/
│   └── codex-review/
│       └── SKILL.md         # Auto-invoke strategy for Claude
├── reviewer.example.json
└── README.md
```

## License

MIT

## Author

[anthhub](https://github.com/anthhub)
