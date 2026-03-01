## ⛔ BASH COMMANDS — ONE COMMAND PER BASH CALL (ZERO EXCEPTIONS)

This is the #1 rule. Violating this rule triggers manual permission approval, which is burdensome to the user.

**ONE Bash tool call = ONE shell command. No exceptions.**

### What counts as a violation

A "compound command" is ANY Bash call containing more than one command, regardless of separator:

| Separator | Example | Violation? |
|-----------|---------|------------|
| `&&` | `cd /path && pytest` | YES |
| `\|\|` | `cmd1 \|\| cmd2` | YES |
| `\|` (pipe) | `pytest 2>&1 \| tail -20` | YES |
| `;` | `cd /path; pytest` | YES |
| **Newline** | `cd /path`↵`pytest` | **YES** — same Bash call = compound |

### Forbidden patterns

```bash
# FORBIDDEN — && chaining
cd /path/to/project && pytest tests/ -v > /tmp/out.out 2>&1

# FORBIDDEN — newline separation (STILL compound in one Bash call!)
cd /path/to/project
PYTHONPATH=src pytest tests/ -v > /tmp/out.out 2>&1

# FORBIDDEN — pipe
pytest tests/ -v 2>&1 | tail -20

# FORBIDDEN — semicolon
cd /path; pytest tests/
```

### Correct patterns

```bash
# Bash call 1:
cd /path/to/project

# Bash call 2 (separate tool invocation):
PYTHONPATH=src pytest tests/ -v > /tmp/out.out 2>&1

# Bash call 3 (separate tool invocation):
tail -20 /tmp/out.out
```

### Pre-check (MANDATORY before every Bash call)

Before executing, verify the command is a **single line with no** `&&`, `||`, `|`, or `;`. If it has multiple lines or any of these operators, split into separate Bash tool calls.

### Subagent rule

This rule applies to ALL subagents. When dispatching Task/Agent, explicitly instruct: **"Execute exactly ONE shell command per Bash tool call. Never combine commands with &&, ||, |, ;, or newlines."**

---

## Project Setup

Consider the following when setting up a new project:

### Service / Process Management
- If the project involves a server or long-running process, plan for **user-level systemd (Ubuntu) / launchd (macOS)** service registration by default.
- Keep service definition files (`.service` / `.plist`) and management scripts inside the repo. When registering the service, link directly to these repo scripts.
- If Dockerization is a natural fit, always prefer it.

### .gitignore Initialization
Include the following in `.gitignore` at project creation:
- `.claude/` — Claude Code working directory
- MCP-related directories: Check `~/.claude/settings.json` or project `.mcp.json` for active MCP servers, and add their output directories (e.g., `.playwright-mcp/`, `.worktrees/`, `docs/plans/`)
- For Python projects: `.venv/`

### Project Memory Initialization
- Create `~/.claude/projects/{project_id}/memory/MEMORY.md` to initialize per-project memory.

---

## Session Start

1. For Python projects, run `source .venv/bin/activate` as a standalone Bash call. All subsequent commands run in the activated environment.
2. Read `~/.claude/projects/{project_id}/memory/MEMORY.md` to restore decisions and lessons from previous sessions. If it does not exist, create it.

---

## Development Workflow

Follow this workflow for all feature/bugfix work:

1. **Setup:** Use `.venv` for Python dependencies. Use `git worktree` to isolate work on a new branch. Base work on the original repo's `.venv`.
2. **Design:** Design → Validate design → If invalid, redesign → Design complete
3. **Plan:** Create implementation plan → Validate plan → If invalid, replan → Plan complete
4. **Implement (TDD per plan task):**
   - Write failing test (RED)
   - Implement until test passes (GREEN)
   - Verify test + implementation correctness → If invalid, restart from test writing
5. **Finalize:** All plan tasks complete → Final test suite + ruff/lint must pass
6. **Merge:** Merge branch to main → Clean up worktree/branch → Update project CLAUDE.md and docs

---

## Development Practices

### Worktree Path Handling
- When working in a worktree, appending the worktree path to commands forces re-approval of already-ALLOWed commands.
- **Always `cd` into the worktree directory first**, then run commands with relative paths so that existing permission patterns remain in effect.

### Memory Management
- When encountering mistakes likely to recur, important architectural decisions, or troubleshooting lessons, update `MEMORY.md` immediately.

### Skill Usage Guidelines
- **Vague / exploratory requests** (not a specific bug fix or feature): Use the `brainstorming` skill.
- **Large feature work**: Use `writing-plans` to create the plan, then `executing-plans` to execute it.
- **After completing each plan step**: Run `code-review`.

### Bug Fixing
- Always reproduce the bug with a failing test FIRST, then fix it.

---

## Development Completion

When the conversation/session is ending (not per-feature, but per-session), perform the following in order:

1. **Skill recommendation:** Based on what was covered in this conversation, determine if there are reusable custom skills worth creating for the current project. If so, recommend them to the user.
2. **Memory update:** Check if `~/.claude/projects/{project_id}/memory/MEMORY.md` needs updates with lessons and decisions from this session.
3. **Branch wrap-up:** Use the `finishing-a-development-branch` skill to clean up and merge the branch.

---

## Communication

If you believe the user's statement is incorrect, say so with your reasoning. The user values honest disagreement over blind agreement.
