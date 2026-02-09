#!/bin/bash
# codex-reviewer.sh - Calls Codex CLI for code review
# Uses terminal's codex command directly, no API key configuration needed

set -e

# Helper function for streaming progress output
progress() {
  echo "[Codex Reviewer] $1" >&2
}

# Security: Sanitize input to prevent shell injection
sanitize_input() {
  # Remove potentially dangerous characters while preserving readability
  # Keep: alphanumeric, spaces, common punctuation, newlines
  echo "$1" | tr -d '\000-\010\013\014\016-\037' | head -c 100000
}

# Security: Create secure temp directory (user-only access)
SECURE_TEMP_DIR="${TMPDIR:-/tmp}/codex-reviewer-$(id -u)"
mkdir -p "$SECURE_TEMP_DIR"
chmod 700 "$SECURE_TEMP_DIR"

# ==================== Load Configuration ====================

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/reviewer.json"

# Default configuration
MODEL="${REVIEWER_MODEL:-gpt-5.2-codex}"
TIMEOUT="${REVIEWER_TIMEOUT:-300}"
SCORE_THRESHOLD="${REVIEWER_SCORE_THRESHOLD:-80}"
BYPASS_APPROVAL="${REVIEWER_BYPASS_APPROVAL:-true}"
SAVE_HISTORY="${REVIEWER_SAVE_HISTORY:-true}"
LANG="${REVIEWER_LANG:-en}"

# Reasoning effort per mode: low (quick) / medium (standard) / high (advanced)
REASONING_EFFORT_QUICK="${REVIEWER_REASONING_QUICK:-low}"
REASONING_EFFORT_STANDARD="${REVIEWER_REASONING_STANDARD:-medium}"
REASONING_EFFORT_ADVANCED="${REVIEWER_REASONING_ADVANCED:-high}"
ADVANCED_TIMEOUT="${REVIEWER_ADVANCED_TIMEOUT:-600}"

# Load from config file if exists
if [ -f "$CONFIG_FILE" ]; then
  MODEL=$(jq -r '.model // "gpt-5.2-codex"' "$CONFIG_FILE" 2>/dev/null || echo "$MODEL")
  TIMEOUT=$(jq -r '.timeout // empty' "$CONFIG_FILE" 2>/dev/null || echo "$TIMEOUT")
  SCORE_THRESHOLD=$(jq -r '.scoreThreshold // 80' "$CONFIG_FILE" 2>/dev/null || echo "$SCORE_THRESHOLD")
  BYPASS_APPROVAL=$(jq -r '.bypassApproval // true' "$CONFIG_FILE" 2>/dev/null || echo "$BYPASS_APPROVAL")
  SAVE_HISTORY=$(jq -r '.saveHistory // empty' "$CONFIG_FILE" 2>/dev/null || echo "$SAVE_HISTORY")
  LANG=$(jq -r '.lang // "en"' "$CONFIG_FILE" 2>/dev/null || echo "$LANG")
  REASONING_EFFORT_QUICK=$(jq -r '.reasoningEffort.quick // "low"' "$CONFIG_FILE" 2>/dev/null || echo "$REASONING_EFFORT_QUICK")
  REASONING_EFFORT_STANDARD=$(jq -r '.reasoningEffort.standard // "medium"' "$CONFIG_FILE" 2>/dev/null || echo "$REASONING_EFFORT_STANDARD")
  REASONING_EFFORT_ADVANCED=$(jq -r '.reasoningEffort.advanced // "high"' "$CONFIG_FILE" 2>/dev/null || echo "$REASONING_EFFORT_ADVANCED")
  ADVANCED_TIMEOUT=$(jq -r '.advancedTimeout // 600' "$CONFIG_FILE" 2>/dev/null || echo "$ADVANCED_TIMEOUT")
fi

# ==================== Parse Arguments ====================

CONTEXT=""
CHANGES=""
ITERATION=0
SESSION_ID="unknown"
CWD="."
USER_REQUIREMENT=""
CONTEXT_FILE_PATH=""
CHANGES_FILE_PATH=""

QUICK_MODE=false
ADVANCED_MODE=false

while [ $# -gt 0 ]; do
  case $1 in
    --context)
      CONTEXT="$2"
      shift 2
      ;;
    --changes)
      CHANGES="$2"
      shift 2
      ;;
    --iteration)
      ITERATION="$2"
      shift 2
      ;;
    --session-id)
      SESSION_ID="$2"
      shift 2
      ;;
    --cwd)
      CWD="$2"
      shift 2
      ;;
    --lang)
      LANG="$2"
      shift 2
      ;;
    --quick|-q)
      QUICK_MODE=true
      shift
      ;;
    --advanced|-a)
      ADVANCED_MODE=true
      shift
      ;;
    --score|-s)
      SCORE_THRESHOLD="$2"
      shift 2
      ;;
    --user-requirement)
      USER_REQUIREMENT="$2"
      shift 2
      ;;
    --context-file)
      CONTEXT_FILE_PATH="$2"
      shift 2
      ;;
    --changes-file)
      CHANGES_FILE_PATH="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# Read from files if provided (supports large context from subagent)
if [ -n "$CONTEXT_FILE_PATH" ] && [ -f "$CONTEXT_FILE_PATH" ]; then
  CONTEXT=$(cat "$CONTEXT_FILE_PATH")
fi
if [ -n "$CHANGES_FILE_PATH" ] && [ -f "$CHANGES_FILE_PATH" ]; then
  CHANGES=$(cat "$CHANGES_FILE_PATH")
fi

# ==================== Language Settings ====================

if [[ "$LANG" == "zh"* ]]; then
  LANG_INSTRUCTION="请使用中文输出审查结果。"
  PASS_LABEL="通过"
  FAIL_LABEL="需要修改"
else
  LANG_INSTRUCTION="Please output the review result in English."
  PASS_LABEL="PASSED"
  FAIL_LABEL="NEEDS WORK"
fi

# ==================== Sanitize Inputs ====================

# Security: Sanitize context and changes to prevent injection
CONTEXT=$(sanitize_input "$CONTEXT")
CHANGES=$(sanitize_input "$CHANGES")
USER_REQUIREMENT=$(sanitize_input "$USER_REQUIREMENT")

# ==================== Quick Mode ====================

if [ "$QUICK_MODE" = true ]; then
  # Build user requirement section for quick mode
  QUICK_USER_REQ=""
  if [ -n "$USER_REQUIREMENT" ]; then
    QUICK_USER_REQ="
User's review focus: $USER_REQUIREMENT
Pay special attention to the above focus area.
"
  fi

  # Quick mode: shorter prompt, faster response
  REVIEW_PROMPT="You are a code reviewer. Review this code briefly.
$LANG_INSTRUCTION
$QUICK_USER_REQ
Context:
$CONTEXT

Code:
$CHANGES

Pass threshold: $SCORE_THRESHOLD/100

Output format (Markdown):
## Score: [0-100]/100
## Verdict: [✅ PASS (score >= $SCORE_THRESHOLD) / ❌ NEEDS WORK]
## Issues (if any):
- [issue]
## Suggestions:
- [suggestion]"

fi

# ==================== Determine Reasoning Effort ====================

if [ "$ADVANCED_MODE" = true ]; then
  REASONING_EFFORT="$REASONING_EFFORT_ADVANCED"
  TIMEOUT="$ADVANCED_TIMEOUT"
  progress "🧠 Advanced mode: $MODEL (reasoning: $REASONING_EFFORT, timeout: ${TIMEOUT}s)"
elif [ "$QUICK_MODE" = true ]; then
  REASONING_EFFORT="$REASONING_EFFORT_QUICK"
  progress "⚡ Quick mode: $MODEL (reasoning: $REASONING_EFFORT, timeout: ${TIMEOUT}s)"
else
  REASONING_EFFORT="$REASONING_EFFORT_STANDARD"
fi

# ==================== Build Review Prompt ====================

# Skip if quick mode already set the prompt
if [ "$QUICK_MODE" != true ]; then
REVIEW_PROMPT="You are a strict technical review expert (Codex Reviewer).
Your task is to review the solutions and code generated by Claude Code as a 'Senior Reviewer' role.

## CRITICAL PRIORITY: Core Path Stability

**Your #1 job is to ensure the core business logic remains stable and correct.**

Before reviewing anything else, you MUST:
1. **Identify the core path** - Which critical business flows do the changes touch? (e.g., auth, payment, data pipeline, API contracts)
2. **Trace upstream impact** - What callers/consumers depend on the changed code? Could they break?
3. **Trace downstream impact** - What does the changed code depend on? Are those assumptions still valid?
4. **Verify behavioral correctness** - Do the changes preserve the expected input→output contract? Are there edge cases that could cause silent data corruption or logic errors in the critical flow?
5. **Check integration boundaries** - Do the changes affect API contracts, database schemas, message formats, or any interface shared with other services/modules?

If the changes touch core business logic, apply **extra scrutiny**. A cosmetic issue is low priority; a subtle bug in the core path that could reach production is a **MUST FIX**.

## Your Responsibilities
1. **Summarize** - Understand the overall approach, summarize the core implementation
2. **Core Path Analysis** - Trace the change through upstream callers and downstream dependencies; verify the critical flow is intact
3. **Find Risks** - Identify potential technical risks and security concerns
4. **Find Bugs** - Discover logic bugs, edge cases, missing exception handling
5. **Find Missing Items** - Check for unconsidered requirements or missing features
6. **Find Issues** - Predict potential runtime problems, performance bottlenecks, maintainability issues

## Review Standards
- **Core Path Integrity** (HIGHEST WEIGHT): Does the change preserve or correctly modify the critical business flow? Is upstream/downstream compatibility maintained?
- Code Quality: Readability, maintainability, naming conventions
- Architecture Design: Module division, dependencies, extensibility
- Security: Input validation, permission control, sensitive data handling
- Robustness: Error handling, edge cases, fault tolerance
- Completeness: Requirement coverage, feature completeness, test coverage

## STRICT RULES: Stay Focused, Minimize Change

**DO NOT:**
- Diverge into unrelated code, files, or modules that the change does not touch
- Suggest refactoring, renaming, or restructuring beyond what is directly needed to fix a real problem
- Propose \"nice-to-have\" improvements, style preferences, or over-engineering
- Recommend changes that could introduce NEW bugs, regressions, or behavioral differences
- Flag cosmetic or stylistic issues as \"Must Fix\"

**DO:**
- Focus ONLY on the code that was actually changed and its direct upstream/downstream impact
- Keep suggestions minimal and surgical — the safest change is the smallest correct change
- Evaluate whether each suggestion itself could introduce new risks; if it could, do NOT suggest it
- Distinguish clearly between real problems (bugs, security, breakage) and minor observations
- When in doubt, leave it alone — stability over perfection

**The goal of this review is to catch real problems, not to rewrite the code.** Every suggestion you make must pass this test: \"Is this change safer than doing nothing?\" If the answer is no, omit it.

## Evidence-Based Review

You have been provided with rich context including:
- Code changes (diff) and recent commit history
- Upstream/downstream dependency analysis (callers and callees of changed code)
- Test results (if available) and build status
- Related source files for cross-referencing

**Use this evidence to make objective judgments.** Do not speculate without basis. When you identify an issue, cite the specific file, function, or line. When test results or dependency traces are provided, cross-reference them against the changes to verify correctness. If evidence shows things are working correctly, acknowledge that — do not invent problems.

## Current Iteration: $((ITERATION + 1))
$(if [ -n "$USER_REQUIREMENT" ]; then
echo "
## User Review Focus
$USER_REQUIREMENT

**IMPORTANT**: Pay special attention to the user's stated focus area above. Prioritize reviewing aspects related to this requirement and provide targeted feedback.
"
fi)
## Conversation Context
$CONTEXT

## Recent Code Changes
$CHANGES

## Output Requirements
$LANG_INSTRUCTION

Please output the review result in the following Markdown format:

---

## 🔍 Codex Review Result

**Score:** [0-100]/100
**Verdict:** [✅ PASS / ❌ NEEDS WORK]

### 📝 Summary
[One paragraph summary of the solution]

### 🔗 Core Path Impact
- **Critical flows affected:** [list which core business paths are touched]
- **Upstream callers at risk:** [list callers that could break, or \"None identified\"]
- **Downstream dependencies:** [list dependencies that could be affected, or \"None identified\"]
- **Behavioral correctness:** [does the change preserve the expected contract?]

### ⚠️ Risks
- [Risk 1]
- [Risk 2]

### 🐛 Issues / Bugs
- [Issue 1]
- [Issue 2]

### 📋 Missing Items
- [Missing 1]
- [Missing 2]

### 🔓 Security Vulnerabilities
- [Vulnerability 1]

### 💡 Suggestions (only if clearly beneficial and low-risk)
- [Suggestion 1]
- [Suggestion 2]

### 🔧 Must Fix (Blocking — real bugs or breakage only)
- [Must fix 1]
- [Must fix 2]

---

## Scoring Standards
- 90-100: Excellent, can pass
- 70-89: Good, minor issues that don't affect core functionality
- 50-69: Average, obvious issues that need fixing
- 0-49: Poor, serious issues that must be fixed

**Core path bugs or upstream/downstream breakage should heavily penalize the score, even if everything else looks clean.**

Only when score >= $SCORE_THRESHOLD AND 'Must Fix' section is empty, verdict can be '✅ PASS'.

Output the Markdown directly without code blocks."
fi  # End of full prompt mode

# ==================== Call Codex CLI ====================

# Security: Use secure temp directory
TEMP_OUTPUT="$SECURE_TEMP_DIR/review-${SESSION_ID}-${ITERATION}.md"
TEMP_PROMPT="$SECURE_TEMP_DIR/prompt-${SESSION_ID}-${ITERATION}.txt"

# Save prompt to temp file (with secure permissions)
echo "$REVIEW_PROMPT" > "$TEMP_PROMPT"
chmod 600 "$TEMP_PROMPT"

# Call Codex CLI
if ! command -v codex > /dev/null 2>&1; then
  progress "⚠️  Codex CLI not installed, skipping review"
  echo "## ⚠️ Codex CLI Not Installed"
  echo ""
  echo "Please install Codex CLI: npm i -g @openai/codex"
  exit 0
fi

# Build Codex command arguments
# Use 'codex exec' for non-interactive mode
CODEX_ARGS="exec --model $MODEL -c reasoning_effort=$REASONING_EFFORT --output-last-message $TEMP_OUTPUT"

# Enable bypass approval if configured (recommended)
if [ "$BYPASS_APPROVAL" = "true" ]; then
  CODEX_ARGS="$CODEX_ARGS --dangerously-bypass-approvals-and-sandbox"
fi

progress "⏳ Waiting for Codex response (model: $MODEL, reasoning: $REASONING_EFFORT, timeout: ${TIMEOUT}s)..."
progress ""

# Execute review with real-time streaming to stderr
# Codex output goes directly to stderr so user can see thinking process
CODEX_EXIT_CODE=0
timeout "$TIMEOUT" codex $CODEX_ARGS "$(cat "$TEMP_PROMPT")" >&2 || CODEX_EXIT_CODE=$?

progress ""

# Check exit status
if [ "$CODEX_EXIT_CODE" -eq 124 ]; then
  progress "⚠️  Review timed out after ${TIMEOUT}s"
elif [ "$CODEX_EXIT_CODE" -ne 0 ]; then
  progress "⚠️  Codex exited with code $CODEX_EXIT_CODE"
else
  progress "✓ Codex response received"
fi

# ==================== Output Result ====================

if [ -f "$TEMP_OUTPUT" ]; then
  progress "📊 Formatting review result..."
  progress ""

  # Output the markdown result to stderr (avoids folding)
  cat "$TEMP_OUTPUT" >&2
  echo "" >&2

  # Save to history if enabled
  if [ "$SAVE_HISTORY" = "true" ]; then
    HISTORY_DIR="$CWD/.claude/review-history/session_$SESSION_ID"
    mkdir -p "$HISTORY_DIR"
    cp "$TEMP_OUTPUT" "$HISTORY_DIR/iteration_$((ITERATION + 1)).md"
  fi
else
  progress "⚠️  Codex review timeout or failed"
  echo ""
  echo "## ⚠️ Review Timeout or Failed"
  echo ""
  echo "Codex failed to complete the review in time. Please try again later."
  echo ""
fi

# Clean up temp files
rm -f "$TEMP_PROMPT" "$TEMP_OUTPUT"
