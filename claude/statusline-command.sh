#!/usr/bin/env bash
# Claude Code statusLine command — plain text (no ANSI codes supported)

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Shorten home directory to ~
home_dir="$HOME"
short_cwd="${cwd/#$home_dir/\~}"

# Hostname and IP
host=$(hostname -s 2>/dev/null || echo "unknown")
ip=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$ip" ] && ip=$(route get default 2>/dev/null | awk '/interface:/{print $2}' | xargs -I{} ipconfig getifaddr {} 2>/dev/null)
[ -z "$ip" ] && ip="127.0.0.1"

# Git branch and status
git_info=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    if git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | grep -q .; then
      dirty="*"
    else
      dirty=""
    fi
    git_info=" (${branch}${dirty})"
  fi
fi

# Context usage
ctx_part=""
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  ctx_part=" [ctx:${used_int}%]"
fi

# Model
model_part=""
if [ -n "$model" ]; then
  model_part=" | ${model}"
fi

printf "%s@%s(%s) %s%s%s%s" "$USER" "$host" "$ip" "$short_cwd" "$git_info" "$ctx_part" "$model_part"
