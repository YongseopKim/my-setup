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
4. **Implement:** Before each task, analyze whether the change could cause **side effects** on other modules or features. Use `executing-plans` skill to execute plan tasks with TDD (RED → GREEN → Verify). Run `code-review` after each plan step. **Commit per task** — every task must produce its own commit.
5. **Review:** After all tasks are complete, run `code-review` on the full set of changes.
6. **Finalize:** Final test suite + ruff/lint must pass
7. **Merge:** Merge branch to main → Clean up worktree/branch → Update project CLAUDE.md and docs

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
- **Checkpoint merge rule:** At each checkpoint, merge all task commits within that group using a **merge commit** (no fast-forward). Verify that every task's commit is included in the merge before proceeding to the next phase.
- Structure plans as: `[Parallel Group A: task1, task2, task3] → Checkpoint: merge + check missing commits + code review + run tests → [Parallel Group B: task4, task5] → Checkpoint: merge + check missing commits + code review + run tests`
- When dispatching subagents, use the `dispatching-parallel-agents` skill for concurrent execution within each group.

### Testing Practices

#### Mock 사용 시 주의사항
- Mock/stub이 실제 동작과 괴리를 만들 수 있음을 항상 인지할 것. 특히 자동 타입 변환, 기본값 주입, 예외 발생 조건 등에서 **Mock은 통과하지만 프로덕션에서 실패하는 케이스**를 경계할 것.
- Mock 대상의 실제 시그니처와 반환값을 확인한 뒤 Mock을 작성할 것.

#### 병렬 테스트 실행
- 리그레션 테스트, 빌드 브레이크 확인, 테스트 베이스라인 체크 등 **전체 테스트 실행** 시에는 병렬 실행을 기본으로 한다.
- 상태 공유, DB 의존성, 파일 I/O 경합 등 **병렬 실행에서 문제될 가능성이 있는 테스트는 제외**한다.
- 병렬 실행에서 실패한 테스트에 한해 **순차 재실행**하여 진짜 실패인지 확인한다.

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
