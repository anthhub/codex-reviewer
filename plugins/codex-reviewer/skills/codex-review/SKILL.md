---
name: codex-review
description: Codex cross-review plugin - when and how to use /cx and /cxx
---

# Codex Review Plugin

This project integrates the Codex Reviewer plugin. `/cx` and `/cxx` let Codex (GPT) act as an independent reviewer to cross-review Claude's code output. `/cx` runs standard review; `/cxx` uses high reasoning effort with deeper context collection for critical changes.

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
| Security-related changes (auth, permissions, keys, input validation) | `Skill(skill="cxx", args="check security-related changes")` |
| User explicitly requests review ("review this", "check this") | `Skill(skill="cx")` or with user-specified focus |
| User requests deep/thorough/advanced review | `Skill(skill="cxx")` or with user-specified focus |

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
Skill(skill="cx")                              General review (score >= 80)
Skill(skill="cx", args="--quick")              Quick review
Skill(skill="cx", args="90")                   Review with score threshold 90
Skill(skill="cx", args="check security")       Focused review
Skill(skill="cx", args="90 check security")    Score 90 + focused
Skill(skill="cx", args="--quick check perf")   Quick + focused
Skill(skill="cxx")                             Advanced review (high reasoning)
Skill(skill="cxx", args="90")                  Advanced + score threshold 90
Skill(skill="cxx", args="check security")      Advanced + focused review
```

### Score Threshold

The pass/fail threshold defaults to **80**. Override per-invocation by passing a number:
- `/cx 90` → must score >= 90 to pass
- `/cx 70 check security` → score 70 + focused on security
- `/cxx 95` → advanced mode, must score >= 95

Can also be set globally in `.claude/reviewer.json` via `"scoreThreshold": 80`.

### `/cxx` - Advanced Mode

`/cxx` uses the same model (`gpt-5.2-codex`) but with **high reasoning effort** and a longer timeout (default 600s). Use it for:
- Complex architectural reviews requiring deep reasoning
- Security audits that need thorough analysis
- Critical code paths where standard review isn't sufficient
- When you need the most thorough review possible

All three modes use the same model with different reasoning intensity:
| Mode | Command | Reasoning Effort | Timeout |
|------|---------|-----------------|---------|
| Quick | `/cx --quick` | low | 300s |
| Standard | `/cx` | medium | 300s |
| Advanced | `/cxx` | high | 600s |

Note: `/cxx` collects more context (800 lines of diff, 10 commits, up to 8 files) for deeper analysis. It does NOT support `--quick` mode.

## Handling Review Results

- Display the Codex review result as-is, without modification or omission
- If Verdict is NEEDS WORK, ask the user whether to apply the feedback
- If there are Must Fix items, proactively suggest fixes
- Do not comment on or dispute Codex's scoring or judgment
