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
You are a code review context-collection agent. Gather relevant code context based on user arguments, then invoke the Codex review script.

User arguments: {{ARGUMENTS}}
Project path: {{PROJECT_DIR}}
Review script: {{SCRIPT_PATH}}

## Step 1: Parse Arguments

Extract from user arguments:
- QUICK_FLAG: if `--quick` or `-q` is present, set to `--quick`; otherwise empty
- USER_REQUIREMENT: the remaining natural-language text after stripping flags (may be empty)

## Step 2: Get Code Changes

Run the following two commands and merge their output into CHANGES_CONTENT:

```bash
cd "{{PROJECT_DIR}}" && git diff --stat -p HEAD 2>/dev/null | head -500
```
```bash
cd "{{PROJECT_DIR}}" && git log --oneline -5 2>/dev/null
```

## Step 3: Search for Relevant Context

If USER_REQUIREMENT is empty, set CONTEXT_CONTENT to "No specific review focus." and skip to Step 4.

If USER_REQUIREMENT is not empty:
1. Extract 2-3 search keywords from USER_REQUIREMENT
2. Use Grep to search {{PROJECT_DIR}} for those keywords (exclude node_modules, .next, dist, .git directories)
3. Use Read to read the most relevant files (up to 5 files, max 200 lines each)
4. Use Glob to find related *.md documentation and Read them

Merge all read content into CONTEXT_CONTENT in this format:

```
=== path/to/file1.ts ===
file content...

=== path/to/file2.ts ===
file content...
```

## Step 4: Write Temp Files and Invoke Review

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
  actual value of QUICK_FLAG

rm -rf "$TEMP_DIR"
```

Note: If USER_REQUIREMENT is empty, omit the --user-requirement parameter. If QUICK_FLAG is empty, omit that flag.

## Step 5: Return Results

The review result is output on stderr. Return the full Markdown content from stderr as the result, formatted as:

```
## Codex Review Result

[paste the Markdown content from stderr as-is]
```

If the codex command is not found, return: Please install Codex CLI: npm i -g @openai/codex

## Constraints

- Read-only (except $TEMP_DIR temp files; do not modify any project files)
- Search scope should focus on USER_REQUIREMENT keywords; do not search unrelated files
- Do not modify or summarize the review result; return it as-is
</SUBAGENT_PROMPT>

Display the subagent's review result without additional modifications.
