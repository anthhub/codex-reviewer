---
name: codex-review
description: Codex cross-review plugin - when and how to use /cx
---

# Codex Review Plugin

This project integrates the Codex Reviewer plugin. The `/cx` command lets Codex (GPT) act as an independent reviewer to cross-review Claude's code output.

## Review Capabilities

`/cx` can review the following dimensions (general review covers all; semantic focus can target any dimension):

| Dimension | Review Scope | Semantic Focus Example |
|-----------|-------------|----------------------|
| Code Quality | Readability, naming, duplicate code | `/cx check code quality` |
| Architecture | Module design, dependencies, extensibility | `/cx review architecture` |
| Security | Input validation, access control, sensitive data | `/cx check security` |
| Robustness | Error handling, edge cases, fault tolerance | `/cx check error handling` |
| Completeness | Requirement coverage, feature completeness, test coverage | `/cx is the feature complete` |
| Performance | Runtime bottlenecks, memory, query efficiency | `/cx check performance` |
| Bugs | Logic errors, boundary conditions, missing exceptions | `/cx find bugs` |

## Auto-Invoke Strategy

Claude should **proactively invoke** Codex cross-review based on actual changes. Use the Skill tool: `Skill(skill="cx", args="<appropriate args>")`.

### Must Auto-Invoke

| Scenario | Invocation |
|----------|-----------|
| Security-related changes (auth, permissions, keys, input validation) | `Skill(skill="cx", args="check security-related changes")` |
| User explicitly requests review ("review this", "check this") | `Skill(skill="cx")` or with user-specified focus |

### Recommended Auto-Invoke

| Scenario | Invocation |
|----------|-----------|
| Modified 3+ files or 100+ lines changed | `Skill(skill="cx")` |
| Refactoring or architecture changes (module structure, interfaces, data flow) | `Skill(skill="cx", args="review architecture changes")` |
| After fixing a bug | `Skill(skill="cx", args="verify the fix is complete")` |
| New core feature added | `Skill(skill="cx", args="review new feature implementation")` |

### Skip Auto-Invoke

- Only comments, docs, or config files changed
- Single-line typo fix
- User explicitly says no review needed
- Pure exploration/research with no code changes

## Invocation

```
Skill(skill="cx")                              General review
Skill(skill="cx", args="--quick")              Quick review
Skill(skill="cx", args="check security")       Focused review
Skill(skill="cx", args="--quick check perf")   Quick + focused
```

## Handling Review Results

- Display the Codex review result as-is, without modification or omission
- If Verdict is NEEDS WORK, ask the user whether to apply the feedback
- If there are Must Fix items, proactively suggest fixes
- Do not comment on or dispute Codex's scoring or judgment
