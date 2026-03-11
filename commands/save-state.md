---
description: Save session state for resumption after /clear.
allowed-tools:
  - Read
  - Bash
  - Write
---

# /save-state

Save the current session state so it can be resumed in a fresh session after `/clear`.

## Steps

### 1. Create session-states directory

```bash
mkdir -p ~/.claude/session-states
```

### 2. Generate structured summary

Review the current session and create a structured summary with these sections. Use 1-5 bullets per section max.

```markdown
# Session State
**Saved:** {YYYY-MM-DD HH:MM}

## What I Was Working On
- [Current task/feature/bug]

## Decisions Made
- [Key choices that affect remaining work]

## Current State
- [What's done, what's in progress]

## Technical Context
- [File paths, patterns, dependencies relevant to resumption]

## Next Steps
- [Exact next action to pick up]

## Open Questions
- [Unresolved items, if any]
```

### 3. Write state file

Write to `~/.claude/session-states/session-state-{YYYY-MM-DDTHH-MM-SS}.md` using a real timestamp from `date`. Use a Bash heredoc:

```bash
date +"%Y-%m-%dT%H-%M-%S"
```

### 4. Prune old states

If more than 10 files in `~/.claude/session-states/`, delete the oldest until exactly 10 remain. Oldest is determined by filename sort (lexicographic).

### 5. Confirm

Print the file path to the user and tell them to run `/clear` to start a fresh session. The saved state will be automatically loaded by the session-start hook.

## Rules

- Use `date` for real timestamps — never fabricate
- 1-5 bullets per section max
- Skip sections that have nothing to report (e.g., no Open Questions)
