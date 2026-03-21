#!/usr/bin/env bash
# Claude Code statusLine command

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_d_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# ── ANSI bright colors ──
BM=$'\e[95m'        # bright magenta
BB=$'\e[94m'        # bright blue
BC=$'\e[96m'        # bright cyan
BW=$'\e[97m'        # bright white
DIM=$'\e[2m'
RST=$'\e[0m'

# ── Fish-style path shortening ──
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

# ── Context usage (percentage only, colored) ──
ctx_part=""
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  if [ "$used_int" -lt 50 ]; then
    ctx_icon="🟢"
  elif [ "$used_int" -lt 80 ]; then
    ctx_icon="🟡"
  else
    ctx_icon="🔴"
  fi
  ctx_part="${DIM}│${RST} ${BW}💬 ${used_int}%${ctx_icon}${RST} "
fi

# ── Plan usage: 5h / 7d (colored) ──
plan_part=""
if [ -n "$five_h_pct" ] && [ -n "$seven_d_pct" ]; then
  fh_int=$(printf "%.0f" "$five_h_pct")
  sd_int=$(printf "%.0f" "$seven_d_pct")
  if [ "$fh_int" -lt 50 ]; then fh_icon="🟢"; elif [ "$fh_int" -lt 80 ]; then fh_icon="🟡"; else fh_icon="🔴"; fi
  if [ "$sd_int" -lt 50 ]; then sd_icon="🟢"; elif [ "$sd_int" -lt 80 ]; then sd_icon="🟡"; else sd_icon="🔴"; fi
  plan_part="${DIM}│${RST} ${BW}⏳ 5h ${fh_int}%${fh_icon} 7d ${sd_int}%${sd_icon}${RST} "
fi

# ── LLM Proxy cost (D/W/T) — hidden if server unreachable ──
proxy_part=""
PROXY_URL="http://localhost:8081"
today_start=$(date -u +%Y-%m-%dT00:00:00Z)
week_start=$(date -u -d 'last sunday' +%Y-%m-%dT00:00:00Z)
today_json=$(curl -s --connect-timeout 1 --max-time 2 "${PROXY_URL}/v1/usage/summary?start=${today_start}" 2>/dev/null)
if [ -n "$today_json" ] && echo "$today_json" | jq -e '.total_cost_usd' >/dev/null 2>&1; then
  week_json=$(curl -s --connect-timeout 1 --max-time 2 "${PROXY_URL}/v1/usage/summary?start=${week_start}" 2>/dev/null)
  total_json=$(curl -s --connect-timeout 1 --max-time 2 "${PROXY_URL}/v1/usage/summary" 2>/dev/null)
  d_cost=$(echo "$today_json" | jq -r '.total_cost_usd // 0')
  w_cost=$(echo "$week_json" | jq -r '.total_cost_usd // 0')
  t_cost=$(echo "$total_json" | jq -r '.total_cost_usd // 0')
  d_fmt=$(printf "%.1f" "$d_cost")
  w_fmt=$(printf "%.1f" "$w_cost")
  t_fmt=$(printf "%.1f" "$t_cost")
  proxy_part="${DIM}│${RST} ${BB}💰 D:\$${d_fmt} W:\$${w_fmt} T:\$${t_fmt}${RST} "
fi

# ── Assemble ──
printf "%s" "${BC}📂 ${short_cwd}${RST} ${git_info}${ctx_part}${plan_part}${proxy_part}${DIM}│${RST}"
