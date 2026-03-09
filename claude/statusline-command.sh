#!/usr/bin/env bash
# Claude Code statusLine command — Unicode icons + actual ANSI escape bytes

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# ── ANSI bright colors (using $'...' for real escape bytes) ──
BG=$'\e[92m'        # bright green
BY=$'\e[93m'        # bright yellow
BR=$'\e[91m'        # bright red
BM=$'\e[95m'        # bright magenta
BB=$'\e[94m'        # bright blue
DIM=$'\e[2m'
RST=$'\e[0m'

# ── Fish-style path shortening ──
# ~/github/YongseopKim/pkb/src/core/utils → ~/g/Y/p/s/c/utils
fish_shorten_path() {
  local p="${1/#$HOME/\~}"
  local IFS='/'
  read -ra parts <<< "$p"
  local last_idx=$(( ${#parts[@]} - 1 ))
  local result=""
  for i in "${!parts[@]}"; do
    local seg="${parts[$i]}"
    if [ "$i" -eq 0 ]; then
      result="$seg"
    elif [ "$i" -eq "$last_idx" ]; then
      result="$result/$seg"
    else
      result="$result/${seg:0:1}"
    fi
  done
  echo "$result"
}
short_cwd=$(fish_shorten_path "$cwd")

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
    # Shorten branch: strip common prefixes, cap at 25 chars
    branch="${branch#feature/}"
    branch="${branch#bugfix/}"
    branch="${branch#hotfix/}"
    branch="${branch#chore/}"
    branch="${branch#fix/}"
    if [ ${#branch} -gt 25 ]; then
      branch="${branch:0:24}…"
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

# ── Model ──
model_part=""
if [ -n "$model" ]; then
  model_part="${DIM}│${RST} ${BB}⚡ ${model}${RST} ${DIM}│${RST}"
fi

# ── Assemble ──
printf "%s" "${BG}📂 ${short_cwd}${RST} ${git_info}${ctx_part}${model_part}"
