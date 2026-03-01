#!/usr/bin/env python3
"""
PreToolUse hook: sub-agent가 절대 경로로 .venv 실행파일을 직접 호출하거나,
프로젝트 경로를 명령어 인자에 절대 경로로 포함하는 패턴을 차단합니다.

차단 시 stderr로 올바른 사용법을 안내하여 agent가 자동으로 재시도하게 합니다.
"""
import json
import sys
import re

try:
    input_data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input", {})
command = tool_input.get("command", "")

if tool_name != "Bash" or not command:
    sys.exit(0)

# Pattern 1: 절대 경로로 .venv/bin/ 실행파일을 직접 호출
# 예: /Users/dragon/github/project/.venv/bin/pip install ...
if re.search(r"/Users/\S+/\.venv/bin/\S+", command):
    print(
        "BLOCKED: 절대 경로로 .venv 실행파일을 호출하지 마세요. "
        "먼저 별도의 Bash call로 'cd <project_dir>'을 실행한 후, "
        "'source .venv/bin/activate'로 가상환경을 활성화하고, "
        "그 다음 별도의 Bash call로 'pip install ...' 같이 명령어만 실행하세요. "
        "각 명령은 반드시 별도의 Bash tool call로 실행해야 합니다.",
        file=sys.stderr,
    )
    sys.exit(2)

# Pattern 2: 명령어 인자에 절대 프로젝트 경로를 포함하여 호출
# 예: pip install -e "/Users/dragon/github/project[dev]"
if re.search(r'(?:pip\s+install|python|pytest)\s+.*"/Users/\S+', command):
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
