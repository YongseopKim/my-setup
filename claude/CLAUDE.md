# Global Claude Code Instructions

> User-wide defaults applied to ALL projects. Project-specific instructions belong in each project's `CLAUDE.md`.

## ⛔ BASH COMMANDS — ONE COMMAND PER BASH CALL (ZERO EXCEPTIONS)

**ONE Bash tool call = ONE shell command. No exceptions.** Enforced by a PreToolUse hook. This rule applies equally to subagents — see "Subagent Rules".

A "compound command" is ANY Bash call containing `&&`, `||`, `|`, `;`, or multiple lines. Before every Bash call, verify the command is a single line with none of these operators. If it fails, split into separate Bash tool calls. Note: redirections like `2>&1` are NOT compound operators and are allowed.

**Never prefix commands with inline env vars** (e.g., `PYTHONPATH=src cmd`). Inline env vars change the command prefix and break `settings.json` allow-pattern matching. Configure env vars in project config files instead.

---

## ⛔ GIT COMMIT — STAGE FILES EXPLICITLY (NO WILDCARDS)

**NEVER use `git add -A`, `git add .`, or any wildcard/glob pattern.** Always stage files individually by explicit path (e.g., `git add src/foo.py`). Only commit files you created or modified — never blindly stage all changes.

---

## ⛔ WORKTREE — NEVER WORK ON MAIN DIRECTLY

**By default, all code changes are done in a git worktree. NEVER modify code directly on the main branch.**

Use the `using-git-worktrees` skill to create and manage worktrees.

### Exceptions (work directly on main)

The following do NOT require a worktree:
- Config/memory files only (CLAUDE.md, MEMORY.md)
- Documentation only (README, comments)
- Meta files only (.gitignore, etc.)
- Infrastructure config only (Docker compose, etc.)
- Read-only tasks with no code modifications (architecture analysis, code review, running tests, etc.)

If the task does not match any exception above, create a worktree.

### Worktree usage rules
- When running commands in a worktree, **always `cd` into the worktree directory first**, then use relative paths. Never append the worktree path to commands (breaks existing ALLOW patterns).
- If the original repo has a `.venv/`, **symlink it into the worktree** (e.g., `ln -s ../../.venv .venv`) so that `.venv/bin/*` commands work with existing allow patterns.

---

## Communication

If you believe the user's statement is incorrect, say so with your reasoning. The user values honest disagreement over blind agreement.

---

## Session Start

1. If `.venv/` exists in the project root, run executables via relative paths: `.venv/bin/python`, `.venv/bin/pip`, `.venv/bin/pytest`.
2. On the first user message, read the project's auto memory `MEMORY.md` to restore decisions and lessons from previous sessions. If it does not exist, create it.
3. Upon receiving a task that **clearly requires code modification**, run `git branch --show-current` before modifying any code. If on main and the task does not match a Worktree exception, create a worktree first. If it is **ambiguous** whether code modification is needed (e.g., "analyze this function", "look into this"), **ask the user** before creating a worktree.

---

## Development Workflow

**Prerequisite:** A worktree has already been created via Session Start step 3. Do NOT create another worktree or branch here.

### Small vs Large

- **Small** (single function edit, one-file bug fix, config change, simple addition): Skip steps 2-3 below. Apply TDD directly: write failing test → implement → verify test passes → commit. If the project has no test infrastructure, ask the user before setting up tests or skipping TDD.
- **Large** (new module, 3+ files modified, API change, architectural impact): Follow all steps below.

**Bug fixes default to Small path** — use the Bug Fixing rules under Development Practices. If the fix spans 3+ files or requires architectural changes, treat as Large.

### Steps

1. **Setup:** Install dependencies if needed.
2. **Design:** Design → Validate → If invalid, redesign → Design complete
3. **Plan:** Use `writing-plans` skill — maximize parallelism with bottleneck checkpoints for testing → Validate → If invalid, replan → Plan complete
4. **Implement:**
   - Before each task, analyze whether the change could cause **side effects** on other modules or features.
   - Use `executing-plans` skill to execute plan tasks with TDD (RED → GREEN → Verify).
   - Run `superpowers:requesting-code-review` at each checkpoint (not every single task).
   - **Commit per task** — every task must produce its own commit.
5. **Review:** After all tasks are complete, run `superpowers:requesting-code-review` on the full set of changes.
6. **Finalize:** Final test suite + linter must pass (e.g., `ruff` for Python, project-specific linter otherwise).
7. **Merge:** Merge branch to main → Clean up worktree/branch → Update project CLAUDE.md and docs

---

## Development Practices

### Memory Management
- When encountering mistakes likely to recur, important architectural decisions, or troubleshooting lessons, update `MEMORY.md` immediately.

### Skill Usage Guidelines
- **Vague / exploratory requests**: Use the `brainstorming` skill.
- **Small changes**: See "Small vs Large" above.
- **Large feature work**: Follow the full Development Workflow.

### Plan Parallelism (Large path only)
- Break down tasks to **maximize parallel execution**. Minimize sequential dependencies.
- Place **bottleneck checkpoints** between parallel groups — run tests at these points before proceeding.
- **Checkpoint merge rule:** At each checkpoint, merge all task commits within that group using a **merge commit** (no fast-forward). Verify that every task's commit is included before proceeding.
- Structure plans as:
  ```
  [Parallel Group A: task1, task2, task3]
    → Checkpoint: merge + check missing commits + code review + run tests
  [Parallel Group B: task4, task5]
    → Checkpoint: merge + check missing commits + code review + run tests
  ```
- Use `dispatching-parallel-agents` skill for concurrent execution within each group.

### Testing Practices

#### Mock usage guidelines
- Mocks can diverge from real behavior. Watch for cases where **mocks pass but production fails** — especially around type coercion, default values, and exceptions.
- Verify the actual signature and return values of the mock target before writing the mock.

#### Parallel test execution
- Default to **parallel execution** for full test runs.
- **Exclude** tests with shared state, DB dependencies, or file I/O contention.
- **Re-run failed tests sequentially** to confirm true failures vs parallelism artifacts.

### Bug Fixing
- Always reproduce the bug with a failing test FIRST, then fix it.
- The failing test and the fix go into a **single commit** (not separate commits).

---

## Development Completion

When the user **explicitly signals the session is ending** (e.g., "let's wrap up the session", "we're done for today", "end session"), perform the following. Do NOT trigger on casual "done" or "that's all" that refer to a single task completion.

1. **Skill recommendation:** Determine if there are reusable custom skills worth creating for the current project.
   - Criteria: patterns repeated 3+ times, project-specific workflows, complex multi-step tasks
2. **Memory update:** Check if `MEMORY.md` needs updates with lessons and decisions from this session.
3. **Branch wrap-up:** Use the `finishing-a-development-branch` skill to clean up and merge.

---

## Subagent Rules (All Dispatched Agents)

When dispatching Task/Agent, ALWAYS include these instructions:
1. **Bash:** "Execute exactly ONE shell command per Bash tool call. Never combine with &&, ||, |, ;, or newlines."
2. **Paths:** "NEVER use absolute paths. `cd` into the project directory first, then use relative paths (`.venv/bin/python`, `.venv/bin/pip`)."
3. **Git:** "NEVER use `git add -A`, `git add .`, or wildcards. Stage files individually by explicit path."
4. **Worktree:** Pass the worktree path and instruct: "Work only inside the given worktree directory."
5. **Environment variables:** "NEVER prefix commands with inline env vars (e.g., `PYTHONPATH=src cmd`). Configure env vars in project config files (pyproject.toml, pytest.ini, conftest.py, etc.). Shell state does not persist across Bash calls, so splitting `export` into a separate call does not work."

### Subagent Bash anti-patterns

```
❌ .venv/bin/pytest tests/ 2>&1 | tail -10       # pipe is a compound operator
❌ PYTHONPATH=src .venv/bin/python -m pytest ...  # inline env var breaks allow patterns
❌ cd /absolute/path && .venv/bin/pytest tests/   # && is a compound operator

✅ .venv/bin/pytest tests/ -q --tb=short          # single command, relative path
✅ .venv/bin/python -m pytest tests/ --tb=short   # single command, no pipe
✅ .venv/bin/pytest tests/ --tb=short 2>&1        # redirection is allowed (not a compound operator)
```
