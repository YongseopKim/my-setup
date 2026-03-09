#!/usr/bin/env bash
# Claude Code statusLine command — Unicode icons + actual ANSI escape bytes

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')

# ── ANSI bright colors (using $'...' for real escape bytes) ──
BOLD=$'\e[1m'
BW=$'\e[97m'       # bright white
BC=$'\e[96m'        # bright cyan
BG=$'\e[92m'        # bright green
BY=$'\e[93m'        # bright yellow
BR=$'\e[91m'        # bright red
BM=$'\e[95m'        # bright magenta
BB=$'\e[94m'        # bright blue
DIM=$'\e[2m'
RST=$'\e[0m'

# ── Shorten home directory to ~ ──
home_dir="$HOME"
short_cwd="${cwd/#$home_dir/\~}"

# ── Hostname and IP ──
host=$(hostname -s 2>/dev/null || echo "unknown")
ip=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$ip" ] && ip="127.0.0.1"

# ── Git branch and status ──
git_info=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    if git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | grep -q .; then
      dirty="✱"
    else
      dirty=""
    fi
    git_info="${DIM}│${RST} ${BM}⎇ ${branch}${dirty}${RST} "
  fi
fi

# ── Context usage with warning levels ──
ctx_part=""
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")

  filled=$((used_int / 10))
  empty=$((10 - filled))
  bar=""
  for ((i=0; i<filled; i++)); do bar+="▓"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done

  if [ "$used_int" -lt 50 ]; then
    ctx_color="${BG}"
    ctx_icon="🟢"
  elif [ "$used_int" -lt 80 ]; then
    ctx_color="${BY}"
    ctx_icon="🟡"
  else
    ctx_color="${BR}"
    ctx_icon="🔴"
  fi

  ctx_part="${DIM}│${RST} ${ctx_color}${ctx_icon} ${bar} ${used_int}%${RST} "
fi

# ── Cost ──
cost_part=""
if [ -n "$cost" ] && [ "$cost" != "0" ]; then
  cost_fmt=$(printf "%.4f" "$cost")
  cost_part="${DIM}│${RST} ${BY}💰 \$${cost_fmt}${RST} "
fi

# ── Duration ──
dur_part=""
if [ -n "$duration_ms" ] && [ "$duration_ms" != "0" ]; then
  total_sec=$((duration_ms / 1000))
  mins=$((total_sec / 60))
  secs=$((total_sec % 60))
  dur_part="${DIM}│${RST} ${BC}⏱ ${mins}m${secs}s${RST} "
fi

# ── Model ──
model_part=""
if [ -n "$model" ]; then
  model_part="${DIM}│${RST} ${BB}⚡ ${model}${RST}"
fi

# ── Assemble ──
printf "%s" "${BW}${BOLD}🖥 ${USER}${RST}${DIM}@${RST}${BC}${host}${RST}${DIM}(${ip})${RST} ${BG}📂 ${short_cwd}${RST} ${git_info}${ctx_part}${cost_part}${dur_part}${model_part}"
