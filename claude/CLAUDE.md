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

## ⛔ WORKTREE — NEVER WORK ON MAIN DIRECTLY

**By default, all code changes are done in a git worktree. NEVER modify code directly on the main branch.**

Use the `using-git-worktrees` skill to create and manage worktrees.

### Exceptions (work directly on main)

The following do NOT require a worktree:
- Editing only config/memory files (CLAUDE.md, MEMORY.md)
- Simple documentation changes (README, comments)
- Meta files only (.gitignore, etc.)
- Infrastructure config only (Docker compose, etc.)

If the task does not match any exception above, create a worktree.

### Worktree usage rules
- When running commands in a worktree, **always `cd` into the worktree directory first**, then use relative paths. Never append the worktree path to commands (breaks existing ALLOW patterns).
- Base work on the original repo's `.venv`.

### Subagent rule
When dispatching subagents, explicitly pass the worktree path and instruct them to **"work only inside the given worktree directory"**.

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
- Create the project's auto memory `MEMORY.md` to initialize per-project memory.

---

## Session Start

1. If `.venv/` exists in the project root, run `source .venv/bin/activate` as a standalone Bash call before running the first shell command. All subsequent commands run in the activated environment.
2. On the first user message, read the project's auto memory `MEMORY.md` to restore decisions and lessons from previous sessions. If it does not exist, create it.
3. Upon receiving a work request, run `git branch --show-current` before modifying any code. If on main and the task does not match a Worktree exception (see above), create a worktree first using the `using-git-worktrees` skill.

---

## Development Workflow

When a worktree is created, follow this workflow. For small, isolated changes, steps 2-3 (Design/Plan) may be skipped.

1. **Setup:** Use `.venv` for Python dependencies. Create a work branch per the Worktree rules (see above).
2. **Design:** Design → Validate design → If invalid, redesign → Design complete
3. **Plan:** Use `writing-plans` skill to create implementation plan — maximize parallelism with bottleneck checkpoints for testing → Validate plan → If invalid, replan → Plan complete
4. **Implement:**
   - Before each task, analyze whether the change could cause **side effects** on other modules or features.
   - Use `executing-plans` skill to execute plan tasks with TDD (RED → GREEN → Verify).
   - Run `code-review` after each plan step.
   - **Commit per task** — every task must produce its own commit.
5. **Review:** After all tasks are complete, run `code-review` on the full set of changes.
6. **Finalize:** Final test suite + ruff/lint must pass
7. **Merge:** Merge branch to main → Clean up worktree/branch → Update project CLAUDE.md and docs

---

## Development Practices

### Memory Management
- When encountering mistakes likely to recur, important architectural decisions, or troubleshooting lessons, update `MEMORY.md` immediately.

### Skill Usage Guidelines
- **Vague / exploratory requests** (not a specific bug fix or feature): Use the `brainstorming` skill.
- **Small / focused changes** (single-file bug fix, minor addition): Apply worktree + TDD directly, skip Design/Plan.
- **Large feature work**: Follow the Development Workflow above.

### Plan Parallelism
- When writing implementation-level plans, break down tasks to **maximize parallel execution**.
- Minimize sequential dependencies to enable concurrent subagent processing.
- Intentionally place **bottleneck checkpoints** between parallel groups — run tests at these points to verify intermediate results before proceeding to the next phase.
- **Checkpoint merge rule:** At each checkpoint, merge all task commits within that group using a **merge commit** (no fast-forward). Verify that every task's commit is included in the merge before proceeding to the next phase.
- Structure plans as: `[Parallel Group A: task1, task2, task3] → Checkpoint: merge + check missing commits + code review + run tests → [Parallel Group B: task4, task5] → Checkpoint: merge + check missing commits + code review + run tests`
- When dispatching subagents, use the `dispatching-parallel-agents` skill for concurrent execution within each group.

### Testing Practices

#### Mock usage guidelines
- Be aware that mocks/stubs can diverge from real behavior. Watch for cases where **mocks pass but production fails** — especially around automatic type coercion, default value injection, and exception conditions.
- Verify the actual signature and return values of the mock target before writing the mock.

#### Parallel test execution
- Default to **parallel execution** for full test runs (regression, build break checks, baseline verification).
- **Exclude** tests with shared state, DB dependencies, or file I/O contention from parallel runs.
- **Re-run failed tests sequentially** to confirm whether they are true failures or parallelism artifacts.

### Bug Fixing
- Always reproduce the bug with a failing test FIRST, then fix it.

---

## Development Completion

When the user signals the session is ending (e.g., "done", "wrap up", "that's all"), perform the following in order:

1. **Skill recommendation:** Based on what was covered in this conversation, determine if there are reusable custom skills worth creating for the current project. If so, recommend them to the user.
2. **Memory update:** Check if the project's auto memory `MEMORY.md` needs updates with lessons and decisions from this session.
3. **Branch wrap-up:** Use the `finishing-a-development-branch` skill to clean up and merge the branch.

---

## Communication

If you believe the user's statement is incorrect, say so with your reasoning. The user values honest disagreement over blind agreement.
