## ⛔ BASH COMMANDS — ONE COMMAND PER BASH CALL (ZERO EXCEPTIONS)

**ONE Bash tool call = ONE shell command. No exceptions.** This is enforced by a PreToolUse hook that blocks violations.

A "compound command" is ANY Bash call containing `&&`, `||`, `|`, `;`, or multiple lines. Before every Bash call, verify the command is a single line with none of these operators. If it fails, split into separate Bash tool calls.

### Subagent rule

This rule applies to ALL subagents. When dispatching Task/Agent, explicitly instruct ALL of the following:
1. **"Execute exactly ONE shell command per Bash tool call. Never combine commands with &&, ||, |, ;, or newlines."**
2. **"NEVER use absolute paths to invoke executables or as command arguments. Always `cd` into the project directory first (separate Bash call), then use relative commands like `pip install`, `pytest`, `python`."**
3. **"NEVER call .venv/bin/* with absolute paths. Instead: (1) cd to project dir, (2) source .venv/bin/activate, (3) run command — each as a separate Bash call."**
4. **"Use relative paths in arguments: `pip install -e '.[dev]'` NOT `pip install -e '/Users/.../project[dev]'`"**

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

1. Before running the first shell command in a Python project, run `source .venv/bin/activate` as a standalone Bash call. All subsequent commands run in the activated environment.
2. On the first user message, read `~/.claude/projects/{project_id}/memory/MEMORY.md` to restore decisions and lessons from previous sessions. If it does not exist, create it.

---

## Development Workflow

Follow this workflow for non-trivial feature/bugfix work (multi-file changes or new functionality). For small, isolated changes, steps 2-3 (Design/Plan) may be skipped.

1. **Setup:** Use `.venv` for Python dependencies. Use `git worktree` to isolate work on a new branch. Base work on the original repo's `.venv`.
2. **Design:** Design → Validate design → If invalid, redesign → Design complete
3. **Plan:** Use `writing-plans` skill to create implementation plan — maximize parallelism with bottleneck checkpoints for testing → Validate plan → If invalid, replan → Plan complete
4. **Implement:** Use `executing-plans` skill to execute plan tasks with TDD (RED → GREEN → Verify). Run `code-review` after each plan step.
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
- **Large feature work**: Follow the Development Workflow above.

### Plan Parallelism
- When writing implementation-level plans, break down tasks to **maximize parallel execution**.
- Minimize sequential dependencies to enable concurrent subagent processing.
- Intentionally place **bottleneck checkpoints** between parallel groups — run tests at these points to verify intermediate results before proceeding to the next phase.
- Structure plans as: `[Parallel Group A: task1, task2, task3] → Checkpoint: run tests → [Parallel Group B: task4, task5] → Checkpoint: run tests`
- When dispatching subagents, use the `dispatching-parallel-agents` skill for concurrent execution within each group.

### Bug Fixing
- Always reproduce the bug with a failing test FIRST, then fix it.

---

## Development Completion

When the user signals the session is ending (e.g., "done", "wrap up", "that's all"), perform the following in order:

1. **Skill recommendation:** Based on what was covered in this conversation, determine if there are reusable custom skills worth creating for the current project. If so, recommend them to the user.
2. **Memory update:** Check if `~/.claude/projects/{project_id}/memory/MEMORY.md` needs updates with lessons and decisions from this session.
3. **Branch wrap-up:** Use the `finishing-a-development-branch` skill to clean up and merge the branch.

---

## Communication

If you believe the user's statement is incorrect, say so with your reasoning. The user values honest disagreement over blind agreement.
