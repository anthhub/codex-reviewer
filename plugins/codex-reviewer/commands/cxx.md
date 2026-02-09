---
name: cxx
description: Codex Review (Advanced - High Reasoning Effort)
---

# Codex Review - Advanced Mode

$ARGUMENTS

Invoke the Task tool (`general-purpose` subagent). Pass the full content of the `<SUBAGENT_PROMPT>` block below as the prompt, replacing only three variables:

- `{{ARGUMENTS}}` → the raw text of `$ARGUMENTS` above
- `{{PROJECT_DIR}}` → the actual value of `$CLAUDE_PROJECT_DIR`
- `{{SCRIPT_PATH}}` → find `codex-reviewer.sh` by running: `find ~/.claude/plugins -name 'codex-reviewer.sh' -path '*/codex-reviewer/*' 2>/dev/null | head -1`. If not found, fall back to `$CLAUDE_PROJECT_DIR/.claude/plugins/codex-reviewer/codex-reviewer.sh`

<SUBAGENT_PROMPT>
You are a code review context-collection agent operating in **advanced mode**. Your job is to gather **deep, comprehensive, evidence-based context** so the Codex reviewer (running with high reasoning effort) can perform a thorough analysis of code quality, core path stability, and upstream/downstream impact.

Advanced mode means: collect MORE context, trace dependencies DEEPER, and provide ALL available verification evidence.

User arguments: {{ARGUMENTS}}
Project path: {{PROJECT_DIR}}
Review script: {{SCRIPT_PATH}}

## Step 1: Parse Arguments

Extract from user arguments:
- SCORE_FLAG: extract score threshold if provided. Supported formats:
  - `/cxx 90` → bare number means score threshold, set SCORE_FLAG to `--score 90`
  - `/cxx --score 90` or `/cxx -s 90` → explicit flag, set SCORE_FLAG to `--score 90`
  - If no score is specified, leave SCORE_FLAG empty (default 80 is used by the script)
  - The number must be 0-100. If it looks like a number but is out of range, ignore it.
- USER_REQUIREMENT: the remaining natural-language text after stripping flags and score number (may be empty)

Examples:
- `/cxx 90` → SCORE_FLAG="--score 90", USER_REQUIREMENT=""
- `/cxx 85 check security` → SCORE_FLAG="--score 85", USER_REQUIREMENT="check security"
- `/cxx check security` → SCORE_FLAG="", USER_REQUIREMENT="check security"

Note: `/cxx` always runs in advanced mode (`--advanced`). The `--quick` flag is NOT supported.

## Step 2: Get Code Changes

Run the following commands and merge their output into CHANGES_CONTENT:

```bash
cd "{{PROJECT_DIR}}" && git diff --stat -p HEAD 2>/dev/null | head -800
```
```bash
cd "{{PROJECT_DIR}}" && git log --oneline -10 2>/dev/null
```
```bash
cd "{{PROJECT_DIR}}" && git log -5 --format="commit %H%nAuthor: %an%nDate: %ad%n%n%s%n%b---" 2>/dev/null
```

Also extract the list of changed files for dependency tracing:

```bash
cd "{{PROJECT_DIR}}" && git diff --name-only HEAD 2>/dev/null
```

## Step 3: Deep Upstream & Downstream Dependency Tracing

This step is critical. Advanced mode traces dependencies more thoroughly.

### 3a: Find upstream callers (who depends on this code?)
- For each changed file, use Grep to search the **entire project** for `import`/`require`/`from` statements referencing the changed file's module name (exclude node_modules, .next, dist, .git, build, vendor)
- Also search for **indirect references**: function names, class names, or exported symbols defined in the changed files
- Read the most relevant upstream callers (up to 8 files, include enough lines to show how the changed code is consumed)

### 3b: Find downstream dependencies (what does this code depend on?)
- Read each changed file fully to understand its imports and dependencies
- Read the key downstream modules it depends on (up to 5 files, focus on the interface/export area and any shared types)

### 3c: Find related test files
- Use Glob to search for test files: `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**`, `**/test_*`, `**/tests/**`
- Match by filename similarity and also by Grep for test files that reference changed functions/classes
- Read ALL matched test files (up to 5 files, full content)

### 3d: Find configuration and schema files
- If changes touch API routes, database models, or config: find related schema files, migration files, route definitions, OpenAPI specs
- Read them (up to 3 files)

Merge all dependency context into DEPENDENCY_CONTENT:

```
=== UPSTREAM CALLERS ===
--- path/to/caller1.ts (imports changed_module) ---
[relevant lines showing how the changed code is used]

--- path/to/caller2.ts (imports changed_module) ---
[relevant lines]

=== DOWNSTREAM DEPENDENCIES ===
--- path/to/dependency1.ts (imported by changed_file) ---
[relevant interface/export lines]

=== RELATED TESTS ===
--- path/to/changed_file.test.ts ---
[full test content]

=== SCHEMAS & CONFIGS ===
--- path/to/schema.prisma ---
[relevant schema]
```

If no upstream/downstream files are found, note "No upstream callers found" or "No downstream dependencies found".

## Step 4: Run Verification Suite

Run ALL applicable verification steps and collect results.

### 4a: Run tests
Try these in order (stop at first success):

```bash
cd "{{PROJECT_DIR}}" && npm test 2>&1 | tail -80
```
```bash
cd "{{PROJECT_DIR}}" && npx jest --no-coverage --verbose 2>&1 | tail -80
```
```bash
cd "{{PROJECT_DIR}}" && python -m pytest --tb=short -v 2>&1 | tail -80
```
```bash
cd "{{PROJECT_DIR}}" && go test -v ./... 2>&1 | tail -80
```
```bash
cd "{{PROJECT_DIR}}" && cargo test 2>&1 | tail -80
```

### 4b: Run type checking (if applicable)
```bash
cd "{{PROJECT_DIR}}" && npx tsc --noEmit 2>&1 | tail -30
```
```bash
cd "{{PROJECT_DIR}}" && npx pyright 2>&1 | tail -30
```
(skip if not applicable)

### 4c: Run linter (if applicable)
```bash
cd "{{PROJECT_DIR}}" && npx eslint --no-fix . 2>&1 | tail -30
```
(skip if not applicable)

### 4d: Run build
```bash
cd "{{PROJECT_DIR}}" && npm run build 2>&1 | tail -30
```
(or the project's equivalent; skip if not applicable)

Merge results into VERIFICATION_CONTENT:
```
=== TEST RESULTS ===
[test output]

=== TYPE CHECK ===
[type check output or "Skipped"]

=== LINT ===
[lint output or "Skipped"]

=== BUILD STATUS ===
[build output or "Skipped"]
```

If a step hangs or fails, record the failure and move on.

## Step 5: Search for Additional Context

If USER_REQUIREMENT is not empty:
1. Extract 2-3 search keywords from USER_REQUIREMENT
2. Use Grep to search {{PROJECT_DIR}} for those keywords (exclude node_modules, .next, dist, .git)
3. Use Read to read the most relevant files (up to 8 files, max 300 lines each)
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

Then use the Bash tool to invoke the review script:

```bash
"{{SCRIPT_PATH}}" \
  --advanced \
  --context-file "$TEMP_DIR/context.txt" \
  --changes-file "$TEMP_DIR/changes.txt" \
  --user-requirement "actual value of USER_REQUIREMENT" \
  --session-id "cxx-$(date +%s)" \
  --cwd "{{PROJECT_DIR}}" \
  actual value of SCORE_FLAG

rm -rf "$TEMP_DIR"
```

Note: If USER_REQUIREMENT is empty, omit the --user-requirement parameter. If SCORE_FLAG is empty, omit it (script defaults to 80). Always include `--advanced`.

## Step 7: Return Results

The review result is output on stderr. Return the full Markdown content from stderr as the result, formatted as:

```
## Codex Review Result (Advanced)

[paste the Markdown content from stderr as-is]
```

If the codex command is not found, return: Please install Codex CLI: npm i -g @openai/codex

## Constraints

- Read-only (except $TEMP_DIR temp files; do not modify any project files)
- Search scope should focus on changed files, their dependencies, and USER_REQUIREMENT keywords
- Do not modify or summarize the review result; return it as-is
- If a verification step hangs or fails, skip it and note the failure; do not block the review
- Prioritize depth over speed: advanced mode should collect as much useful evidence as possible
</SUBAGENT_PROMPT>

Display the subagent's review result without additional modifications.
