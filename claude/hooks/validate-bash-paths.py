#!/usr/bin/env python3
"""
PreToolUse hook for Bash commands:
1. 복합 커맨드 차단 (&&, ||, ;, 멀티라인)
2. 파이프(|)는 모든 세그먼트가 화이트리스트에 있으면 허용
3. 절대 경로로 .venv 실행파일 직접 호출 차단
4. 명령어 인자에 절대 프로젝트 경로 포함 차단

차단 시 stderr로 올바른 사용법을 안내하여 agent가 자동으로 재시도하게 합니다.
"""
import json
import sys
import re

# 파이프 체인에서 허용되는 커맨드 화이트리스트
# 각 세그먼트의 첫 번째 토큰(커맨드명)이 이 목록에 있으면 허용
PIPE_SAFE_COMMANDS = {
    # 읽기/탐색
    "cat", "head", "tail", "less", "wc", "find", "ls",
    "stat", "file", "diff",
    # 필터/변환
    "grep", "rg", "sort", "uniq", "cut", "awk", "sed", "tr", "jq",
    # 출력
    "tee", "xargs",
    # git
    "git",
    # 개발 도구
    "pip", "pytest", "ruff",
    ".venv/bin/pip", ".venv/bin/pytest",
    # 컨테이너
    "docker",
    # 기타
    "echo", "printf",
}


def get_command_name(segment: str) -> str:
    """파이프 세그먼트에서 커맨드명을 추출한다.

    예: "  git log --oneline" -> "git"
        ".venv/bin/pip list" -> ".venv/bin/pip"
    """
    tokens = segment.strip().split()
    if not tokens:
        return ""
    return tokens[0]

try:
    input_data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input", {})
command = tool_input.get("command", "")

if tool_name != "Bash" or not command:
    sys.exit(0)


def strip_quotes(cmd: str) -> str:
    """따옴표 안의 내용을 제거하여 연산자 오탐을 방지."""
    return re.sub(r"""'[^']*'|"[^"]*"|`[^`]*`""", '""', cmd)


# Pattern 0: 복합 커맨드 차단 (&&, ||, |, ;, 멀티라인)
stripped = strip_quotes(command)

# 멀티라인 허용 패턴: git + HEREDOC (git commit -m "$(cat <<'EOF' ...)")
def is_git_heredoc(cmd: str) -> bool:
    """git 커맨드가 HEREDOC으로 멀티라인 인자를 전달하는 패턴인지 확인."""
    first_token = cmd.strip().split()[0] if cmd.strip() else ""
    return first_token == "git" and "<<" in cmd

# 멀티라인 체크
if "\n" in command.strip() and not is_git_heredoc(command):
    print(
        "BLOCKED: 멀티라인 커맨드는 허용되지 않습니다. "
        "각 명령을 별도의 Bash tool call로 분리하세요.",
        file=sys.stderr,
    )
    sys.exit(2)

# &&, ||, ; 체크 (따옴표 밖에서만) — 무조건 차단
compound_match = re.search(r"&&|\|\||(?<=\S)\s*;\s*(?=\S)", stripped)
if compound_match:
    op = compound_match.group().strip()
    print(
        f"BLOCKED: 복합 연산자 '{op}'가 감지되었습니다. "
        "하나의 Bash tool call에는 하나의 명령만 실행하세요. "
        "여러 명령을 실행하려면 각각 별도의 Bash tool call로 분리하세요.",
        file=sys.stderr,
    )
    sys.exit(2)

# 파이프(|) 체크 — 화이트리스트 기반 허용
pipe_match = re.search(r"(?<![<>2&])\|(?!\|)", stripped)
if pipe_match:
    segments = re.split(r"(?<![<>2&])\|(?!\|)", stripped)
    blocked_cmds = []
    for seg in segments:
        cmd_name = get_command_name(seg)
        if cmd_name not in PIPE_SAFE_COMMANDS:
            blocked_cmds.append(cmd_name or "(empty)")
    if blocked_cmds:
        print(
            f"BLOCKED: 파이프 체인에 허용되지 않은 커맨드가 포함되어 있습니다: {blocked_cmds}. "
            "파이프는 화이트리스트에 등록된 커맨드끼리만 사용할 수 있습니다. "
            "각 명령을 별도의 Bash tool call로 분리하세요.",
            file=sys.stderr,
        )
        sys.exit(2)

# Pattern 1: 절대 경로로 .venv/bin/ 실행파일을 직접 호출
# 예: /Users/dragon/github/project/.venv/bin/pip install ...
# 예: /home/dragon/mywork/project/.venv/bin/python -m pytest ...
if re.search(r"(?:/Users|/home)/\S+/\.venv/bin/\S+", command):
    print(
        "BLOCKED: 절대 경로로 .venv 실행파일을 호출하지 마세요. "
        "먼저 별도의 Bash call로 'cd <project_dir>'을 실행한 후, "
        "'.venv/bin/python', '.venv/bin/pip' 등 상대 경로로 직접 실행하세요. "
        "각 명령은 반드시 별도의 Bash tool call로 실행해야 합니다.",
        file=sys.stderr,
    )
    sys.exit(2)

# Pattern 2: 명령어 인자에 절대 프로젝트 경로를 포함하여 호출
# 예: pip install -e "/Users/dragon/github/project[dev]"
# 예: pip install -e "/home/dragon/mywork/project[dev]"
if re.search(r'(?:pip\s+install|python|pytest)\s+.*"(?:/Users|/home)/\S+', command):
    print(
        "BLOCKED: 명령어 인자에 절대 경로를 사용하지 마세요. "
        "먼저 별도의 Bash call로 'cd <project_dir>'을 실행한 후, "
        "상대 경로를 사용하세요. "
        "예: pip install -e '.[dev]' (절대 경로 대신 상대 경로 사용). "
        "각 명령은 반드시 별도의 Bash tool call로 실행해야 합니다.",
        file=sys.stderr,
    )
    sys.exit(2)

sys.exit(0)
