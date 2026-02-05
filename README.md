# Codex Reviewer

A Claude Code plugin that enables dual AI cross-validation using Codex CLI (GPT-4) as a Senior Reviewer.

## Features

- **Dual AI Verification**: Claude Code generates solutions, Codex reviews them
- **Multiple Review Modes**:
  - Review all uncommitted changes
  - Review specific files
  - Review staged changes only
  - Review specific commits
  - Quick review mode (faster, shorter)
- **Security Hardened**: Input sanitization, secure temp directories, path validation
- **History Tracking**: Saves review history for future reference
- **Configurable**: Customizable model, timeout, score threshold, and language

## Installation

### Prerequisites

- [Claude Code](https://claude.ai/code) CLI installed
- [Codex CLI](https://github.com/openai/codex) installed (`npm i -g @openai/codex`)
- `jq` for JSON parsing (`brew install jq`)

### Install the Plugin

1. Copy the plugin to your Claude Code plugins directory:

```bash
mkdir -p .claude/plugins
cp -r hooks .claude/plugins/codex-reviewer/
```

2. Copy the command files to your project:

```bash
mkdir -p .claude/commands
cp commands/cx*.md .claude/commands/
```

3. (Optional) Create a configuration file:

```bash
cp reviewer.example.json .claude/reviewer.json
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `/cx` | Review all uncommitted changes |
| `/cx <file>` | Review specific file |
| `/cx --staged` | Review only staged changes |
| `/cx --quick` | Quick review (faster) |
| `/cx -c HEAD~1` | Review specific commit |
| `/cx-history` | View review history |
| `/cx-clear` | Clear review history |
| `/cx-check` | Check configuration and dependencies |

### Examples

```bash
# Review all uncommitted changes
/cx

# Review a specific file
/cx src/app.ts

# Quick review of staged changes
/cx --staged --quick

# Review the last commit
/cx -c HEAD~1

# Clear old history (keep last 7 days)
/cx-clear --days 7
```

## Configuration

Create `.claude/reviewer.json` in your project root:

```json
{
  "model": "gpt-5.2-codex",
  "timeout": 300,
  "scoreThreshold": 85,
  "lang": "en",
  "saveHistory": true,
  "bypassApproval": true,
  "contextLines": 50
}
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `model` | `gpt-5.2-codex` | Codex model to use |
| `timeout` | `300` | Timeout in seconds |
| `scoreThreshold` | `85` | Minimum score to pass (0-100) |
| `lang` | `en` | Output language (`en` or `zh-CN`) |
| `saveHistory` | `true` | Save review history |
| `bypassApproval` | `true` | Skip Codex approval prompts |
| `contextLines` | `50` | Lines of context to include |

### Environment Variables

You can also configure via environment variables:

```bash
export REVIEWER_MODEL="gpt-5.2-codex"
export REVIEWER_TIMEOUT=300
export REVIEWER_SCORE_THRESHOLD=85
export REVIEWER_LANG="en"
```

## Review Output

The reviewer outputs a structured Markdown report:

```markdown
## Codex Review Result

**Score:** 85/100
**Verdict:** PASS

### Summary
[One paragraph summary]

### Risks
- [Risk items]

### Issues / Bugs
- [Issue items]

### Security Vulnerabilities
- [Vulnerability items]

### Suggestions
- [Suggestion items]

### Must Fix (Blocking)
- [Blocking issues that must be fixed]
```

## Scoring Standards

| Score | Rating | Description |
|-------|--------|-------------|
| 90-100 | Excellent | Ready to pass |
| 70-89 | Good | Minor issues, doesn't affect core functionality |
| 50-69 | Average | Obvious issues need fixing |
| 0-49 | Poor | Serious issues must be fixed |

A review passes only when:
- Score >= threshold (default 85)
- "Must Fix" section is empty

## Security

This plugin implements several security measures:

- **Input Sanitization**: Removes potentially dangerous characters from inputs
- **Secure Temp Directory**: Uses user-specific temp directory with 700 permissions
- **Path Validation**: Prevents directory traversal attacks
- **Commit Validation**: Validates commit hash format before use

## File Structure

```
codex-reviewer/
├── hooks/
│   ├── codex-reviewer.sh    # Core review script
│   ├── manual-review.sh     # Manual trigger entry point
│   ├── stop-review.sh       # Stop hook (optional)
│   ├── clear-history.sh     # History cleanup
│   └── check-health.sh      # Health check
├── commands/
│   ├── cx.md                # Main review command
│   ├── cx-history.md        # History command
│   ├── cx-clear.md          # Clear command
│   └── cx-check.md          # Check command
├── reviewer.example.json    # Example configuration
└── README.md
```

## License

MIT

## Author

[anthhub](https://github.com/anthhub)
