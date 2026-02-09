---
name: cx
description: Codex Review
---

# Codex Review

$ARGUMENTS

Invoke the Task tool (`general-purpose` subagent). Pass the full content of the `<SUBAGENT_PROMPT>` block below as the prompt, replacing only three variables:

- `{{ARGUMENTS}}` → the raw text of `$ARGUMENTS` above
- `{{PROJECT_DIR}}` → the actual value of `$CLAUDE_PROJECT_DIR`
- `{{SCRIPT_PATH}}` → find `codex-reviewer.sh` by running: `find ~/.claude/plugins -name 'codex-reviewer.sh' -path '*/codex-reviewer/*' 2>/dev/null | head -1`. If not found, fall back to `$CLAUDE_PROJECT_DIR/.claude/plugins/codex-reviewer/codex-reviewer.sh`

<SUBAGENT_PROMPT>
You are a code review context-collection agent. Your job is to gather **comprehensive, evidence-based context** so the Codex reviewer can make objective judgments about code quality and core path stability.

User arguments: {{ARGUMENTS}}
Project path: {{PROJECT_DIR}}
Review script: {{SCRIPT_PATH}}

## Step 1: Parse Arguments

Extract from user arguments:
- QUICK_FLAG: if `--quick` or `-q` is present, set to `--quick`; otherwise empty
- SCORE_FLAG: extract score threshold if provided. Supported formats:
  - `/cx 80` → bare number means score threshold, set SCORE_FLAG to `--score 80`
  - `/cx --score 80` or `/cx -s 80` → explicit flag, set SCORE_FLAG to `--score 80`
  - If no score is specified, leave SCORE_FLAG empty (default 80 is used by the script)
  - The number must be 0-100. If it looks like a number but is out of range, ignore it.
- USER_REQUIREMENT: the remaining natural-language text after stripping flags and score number (may be empty)

Examples:
- `/cx 90` → QUICK_FLAG="", SCORE_FLAG="--score 90", USER_REQUIREMENT=""
- `/cx 90 check security` → QUICK_FLAG="", SCORE_FLAG="--score 90", USER_REQUIREMENT="check security"
- `/cx --quick 70` → QUICK_FLAG="--quick", SCORE_FLAG="--score 70", USER_REQUIREMENT=""
- `/cx check security` → QUICK_FLAG="", SCORE_FLAG="", USER_REQUIREMENT="check security"

## Step 2: Get Code Changes

Run the following commands and merge their output into CHANGES_CONTENT:

```bash
cd "{{PROJECT_DIR}}" && git diff --stat -p HEAD 2>/dev/null | head -500
```
```bash
cd "{{PROJECT_DIR}}" && git log --oneline -5 2>/dev/null
```

Also extract the list of changed files for dependency tracing in Step 3:

```bash
cd "{{PROJECT_DIR}}" && git diff --name-only HEAD 2>/dev/null
```

## Step 3: Trace Upstream & Downstream Dependencies

This step is critical for core path analysis. For each changed file from Step 2:

### 3a: Find upstream callers (who depends on this code?)
- Use Grep to search the project for `import` or `require` statements referencing the changed file's module name (exclude node_modules, .next, dist, .git, build)
- Read the most relevant upstream callers (up to 5 files, focus on the import/usage area)

### 3b: Find downstream dependencies (what does this code depend on?)
- Read each changed file and identify its imports/requires
- Read the key downstream modules it depends on (up to 3 files, focus on the interface/export area)

### 3c: Find related test files
- Use Glob to search for test files related to the changed files: `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**`
- Match by filename similarity (e.g., if `auth.ts` changed, look for `auth.test.ts`, `auth.spec.ts`)
- Read matched test files (up to 3 files)

Merge all dependency context into DEPENDENCY_CONTENT in this format:

```
=== UPSTREAM CALLERS ===
--- path/to/caller1.ts (imports changed_file) ---
[relevant lines showing how the changed code is used]

--- path/to/caller2.ts (imports changed_file) ---
[relevant lines]

=== DOWNSTREAM DEPENDENCIES ===
--- path/to/dependency1.ts (imported by changed_file) ---
[relevant interface/export lines]

=== RELATED TESTS ===
--- path/to/changed_file.test.ts ---
[test content]
```

If no upstream/downstream files are found, note "No upstream callers found" or "No downstream dependencies found" respectively.

## Step 4: Run Verification (if available)

Attempt to run project tests and collect results. Try these in order (stop at first success):

```bash
cd "{{PROJECT_DIR}}" && npm test 2>&1 | tail -50
```
```bash
cd "{{PROJECT_DIR}}" && npx jest --no-coverage 2>&1 | tail -50
```
```bash
cd "{{PROJECT_DIR}}" && python -m pytest --tb=short 2>&1 | tail -50
```
```bash
cd "{{PROJECT_DIR}}" && go test ./... 2>&1 | tail -50
```
```bash
cd "{{PROJECT_DIR}}" && cargo test 2>&1 | tail -50
```

If none work or no test framework is detected, set VERIFICATION_CONTENT to "No test framework detected or tests not configured."

Also try a quick build check:
```bash
cd "{{PROJECT_DIR}}" && npm run build 2>&1 | tail -30
```
(or the project's equivalent build command; skip if not applicable)

Merge results into VERIFICATION_CONTENT:
```
=== TEST RESULTS ===
[test output]

=== BUILD STATUS ===
[build output or "Build check skipped"]
```

## Step 5: Search for Additional Context

If USER_REQUIREMENT is not empty:
1. Extract 2-3 search keywords from USER_REQUIREMENT
2. Use Grep to search {{PROJECT_DIR}} for those keywords (exclude node_modules, .next, dist, .git)
3. Use Read to read the most relevant files (up to 5 files, max 200 lines each)
4. Use Glob to find related *.md documentation and Read them

Merge into EXTRA_CONTEXT. If USER_REQUIREMENT is empty, set EXTRA_CONTEXT to empty string.

## Step 6: Assemble and Invoke Review

Combine all collected context into CONTEXT_CONTENT:

```
CONTEXT_CONTENT = DEPENDENCY_CONTENT + "\n\n" + VERIFICATION_CONTENT + "\n\n" + EXTRA_CONTEXT
```

```bash
TEMP_DIR=$(mktemp -d)
```

Use the Write tool to create two files:
- `$TEMP_DIR/context.txt` ← full content of CONTEXT_CONTENT
- `$TEMP_DIR/changes.txt` ← full content of CHANGES_CONTENT

Then use the Bash tool to invoke the review script (substitute actual values):

```bash
"{{SCRIPT_PATH}}" \
  --context-file "$TEMP_DIR/context.txt" \
  --changes-file "$TEMP_DIR/changes.txt" \
  --user-requirement "actual value of USER_REQUIREMENT" \
  --session-id "cx-$(date +%s)" \
  --cwd "{{PROJECT_DIR}}" \
  actual value of QUICK_FLAG \
  actual value of SCORE_FLAG

rm -rf "$TEMP_DIR"
```

Note: If USER_REQUIREMENT is empty, omit the --user-requirement parameter. If QUICK_FLAG is empty, omit that flag. If SCORE_FLAG is empty, omit it (script defaults to 80).

## Step 7: Return Results

The review result is output on stderr. Return the full Markdown content from stderr as the result, formatted as:

```
## Codex Review Result

[paste the Markdown content from stderr as-is]
```

If the codex command is not found, return: Please install Codex CLI: npm i -g @openai/codex

## Constraints

- Read-only (except $TEMP_DIR temp files; do not modify any project files)
- Search scope should focus on changed files and USER_REQUIREMENT keywords; do not search unrelated files
- Do not modify or summarize the review result; return it as-is
- If a verification step hangs or fails, skip it and note the failure; do not block the review
</SUBAGENT_PROMPT>

Display the subagent's review result without additional modifications.
