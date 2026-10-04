#!/usr/bin/env bash
#==============================================================================
# System Health Check Report
# Thresholds:  <75% OK (green) | 75-<90% WARNING (yellow) | >=90% CRITICAL (red)
# Usage:       ./health_check.sh [--plain]     (--plain = no ANSI colours)
# Test hooks:  WARN_T / CRIT_T env vars override thresholds (testing only)
#==============================================================================
export LC_ALL=C

WARN_T=${WARN_T:-75}
CRIT_T=${CRIT_T:-90}

# ---- colour handling (auto-off when not a terminal, e.g. cron/mail) ----------
USE_COLOR=1
[[ "$1" == "--plain" || ! -t 1 || -n "$NO_COLOR" ]] && USE_COLOR=0
[[ "$1" == "--color" ]] && USE_COLOR=1

if (( USE_COLOR )); then
  RST=$'\033[0m'; BOLD=$'\033[1m'
  C_GRN=$'\033[1;32m'
  C_YEL=$'\033[1;30;43m'   # black text on yellow background (highlight)
  C_RED=$'\033[1;97;41m'   # white text on red background (highlight)
else
  RST=""; BOLD=""; C_GRN=""; C_YEL=""; C_RED=""
fi

LINE="----------------------------------------------------------------------"

# ---- status helper: takes an integer/float percent, prints coloured status ---
status() {
  local pct=${1%.*}; pct=${pct:-0}
  if   (( pct >= CRIT_T )); then printf '%s🔴 CRITICAL%s' "$C_RED" "$RST"
  elif (( pct >= WARN_T )); then printf '%s🟡 WARNING %s'  "$C_YEL" "$RST"
  else                           printf '%s🟢 OK       %s'  "$C_GRN" "$RST"
  fi
}

# ---- header ------------------------------------------------------------------
os_name=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
[[ -z "$os_name" ]] && os_name=$(uname -s)
uptime_str=$(uptime -p 2>/dev/null | sed 's/^up //')
[[ -z "$uptime_str" ]] && uptime_str=$(uptime | sed 's/.*up *\([^,]*\),.*/\1/')

echo "${BOLD}-------------System Health Check Report-----------------${RST}"
printf '%-18s: %s\n' "OS"              "$os_name"
printf '%-18s: %s\n' "Kernel version"  "$(uname -r)"
printf '%-18s: %s\n' "Hostname"        "$(hostname)"
printf '%-18s: %s\n' "System uptime"   "$uptime_str"
printf '%-18s: %s\n' "Date and time"   "$(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$LINE"

# ---- CPU (whole system, sampled from /proc/stat over 1 second) ---------------
read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
idle1=$((i1 + w1));  idle2=$((i2 + w2))
tot1=$((u1+n1+s1+i1+w1+q1+sq1+st1)); tot2=$((u2+n2+s2+i2+w2+q2+sq2+st2))
dt=$((tot2 - tot1)); di=$((idle2 - idle1))
if (( dt > 0 )); then cpu_pct=$(awk -v dt="$dt" -v di="$di" 'BEGIN{printf "%.1f",(dt-di)*100/dt}')
else cpu_pct="0.0"; fi
cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
printf '%-18s: %5s%%  %s  (cores: %s)\n' "CPU usage" "$cpu_pct" "$(status "$cpu_pct")" "$cores"

# ---- Memory ------------------------------------------------------------------
mem_total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
mem_avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
[[ -z "$mem_avail_kb" ]] && mem_avail_kb=$(awk '/^(MemFree|Buffers|Cached):/{s+=$2} END{print s}' /proc/meminfo)
mem_used_kb=$((mem_total_kb - mem_avail_kb))
mem_pct=$(awk -v u="$mem_used_kb" -v t="$mem_total_kb" 'BEGIN{printf "%.1f",u*100/t}')
mem_total_h=$(awk -v k="$mem_total_kb" 'BEGIN{printf "%.2f GB",k/1048576}')
mem_used_h=$(awk  -v k="$mem_used_kb"  'BEGIN{printf "%.2f GB",k/1048576}')
printf '%-18s: %5s%%  %s  (Total: %s | Used: %s)\n' "Memory usage" "$mem_pct" "$(status "$mem_pct")" "$mem_total_h" "$mem_used_h"
echo "$LINE"

# ---- Disk & Inode (real filesystems only) ------------------------------------
FS_EXCL=(-x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x iso9660)

print_fs_table() {  # $1 = "disk" | "inode"
  local flag="-hP"; [[ "$1" == "inode" ]] && flag="-iP"
  printf '%s%-26s %9s %9s %7s   %s%s\n' "$BOLD" "Filesystem / Mount" "Size" "Used" "Use%" "Status" "$RST"
  df $flag "${FS_EXCL[@]}" 2>/dev/null | awk 'NR>1' | sort -u -k1,1 | \
  while read -r fs size used avail pct mnt; do
    p=${pct%\%}
    [[ "$p" =~ ^[0-9]+$ ]] || continue          # skip filesystems with no inodes ("-")
    printf '%-26s %9s %9s %6s%%   %s\n' "${mnt:0:26}" "$size" "$used" "$p" "$(status "$p")"
  done
}

echo "${BOLD}Disk usage:${RST}"
print_fs_table disk
echo
echo "${BOLD}Inode usage:${RST}"
print_fs_table inode
echo "$LINE"

# ---- Top 5 processes by CPU --------------------------------------------------
echo "${BOLD}Top 5 services (by %CPU):${RST}"
printf '%s%-8s %-22s %-14s %6s%s\n' "$BOLD" "PID" "PROCESS NAME" "USER" "%CPU" "$RST"
printf '%-8s %-22s %-14s %6s\n' "--------" "----------------------" "--------------" "------"
ps -eo pid=,comm=,user:14=,%cpu= --sort=-%cpu 2>/dev/null | head -n 5 | \
while read -r pid comm user cpu; do
  printf '%-8s %-22s %-14s %6s\n' "$pid" "${comm:0:22}" "${user:0:14}" "$cpu"
done
echo "$LINE"
echo "Legend: 🟢 <${WARN_T}% OK | 🟡 ${WARN_T}-<${CRIT_T}% WARNING | 🔴 >=${CRIT_T}% CRITICAL"
