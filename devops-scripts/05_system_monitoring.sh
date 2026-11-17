#!/usr/bin/env bash
# ============================================================
# CATEGORY 5: SYSTEM MONITORING AND DISK
# Topics: CPU, memory, disk, load, inodes, alerts, health report
# Usage : ./05_system_monitoring.sh <task> [args]
# ============================================================
set -euo pipefail

# --- Task 1: system information ------------------------------
sysinfo() {
  echo "Host    : $(hostname)"
  echo "OS      : $(grep -m1 PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
  echo "Kernel  : $(uname -r)"
  echo "Uptime  : $(uptime -p)"
  echo "CPUs    : $(nproc)"
  echo "Memory  : $(free -h | awk '/^Mem:/ { print $3 " used of " $2 }')"
  echo "IP      : $(hostname -I 2>/dev/null | awk '{ print $1 }')"
}

# --- helpers that print one number ---------------------------
cpu_used() {   # CPU use in percent, measured over 1 second
  local a b
  read -r _ a1 a2 a3 a4 a5 a6 a7 _ < /proc/stat; sleep 1
  read -r _ b1 b2 b3 b4 b5 b6 b7 _ < /proc/stat
  a=$(( a1 + a2 + a3 + a4 + a5 + a6 + a7 )); b=$(( b1 + b2 + b3 + b4 + b5 + b6 + b7 ))
  echo $(( 100 * ( (b - a) - (b4 - a4) ) / (b - a) ))
}
mem_used()  { free | awk '/^Mem:/ { printf "%d", ($2 - $7) * 100 / $2 }'; }
disk_used() { df -P "${1:-/}" | awk 'NR == 2 { gsub("%", "", $5); print $5 }'; }

# --- Task 2: disk alert (most common exam question) ----------
disk_alert() {
  local limit="${1:-80}" bad=0
  while read -r fs _ _ _ pct mount; do
    pct="${pct%\%}"
    if (( pct >= limit )); then
      echo "WARNING: $mount ($fs) is ${pct}% full"; bad=1
    fi
  done < <(df -P -x tmpfs -x devtmpfs -x overlay -x squashfs | tail -n +2)
  (( bad )) || echo "OK: all disks are under ${limit}%"
  return "$bad"
}

# --- Task 3: CPU and memory alert ----------------------------
cpu_alert() {
  local limit="${1:-80}" now; now=$(cpu_used)
  (( now >= limit )) && { echo "WARNING: CPU ${now}%"; return 1; } || echo "OK: CPU ${now}%"
}
mem_alert() {
  local limit="${1:-80}" now; now=$(mem_used)
  (( now >= limit )) && { echo "WARNING: memory ${now}%"; return 1; } || echo "OK: memory ${now}%"
}

# --- Task 4: load average check ------------------------------
load_alert() {
  local cores load1; cores=$(nproc); load1=$(cut -d' ' -f1 /proc/loadavg)
  if awk -v l="$load1" -v c="$cores" 'BEGIN { exit !(l > c) }'; then
    echo "WARNING: load $load1 is higher than $cores cores"; return 1
  fi
  echo "OK: load $load1 on $cores cores"
}

# --- Task 5: inode use ---------------------------------------
inode_alert() {
  local limit="${1:-80}"
  df -Pi | awk -v l="$limit" 'NR > 1 && $5 + 0 >= l { print "WARNING: inodes " $5 " on " $6; bad = 1 }
                              END { if (!bad) print "OK: inodes fine" }'
}

# --- Task 6: what is using the disk? -------------------------
disk_hogs() {
  local dir="${1:-/var}" n="${2:-10}"
  du -xh --max-depth=1 "$dir" 2>/dev/null | sort -rh | head -n "$n"
}

# --- Task 7: full health report ------------------------------
report() {
  echo "===== HEALTH REPORT $(date '+%F %T') ====="
  sysinfo; echo
  echo "-- CPU / Memory / Load --"
  cpu_alert "${1:-80}" || true; mem_alert "${1:-80}" || true; load_alert || true; echo
  echo "-- Disk --";  disk_alert "${1:-80}" || true; inode_alert "${1:-80}"; echo
  echo "-- Top 5 by memory --"; ps -eo pid,%mem,%cpu,comm --sort=-%mem | head -n 6
}

# --- Task 8: send an alert only when something is wrong ------
# Cron example: */10 * * * * /path/05_system_monitoring.sh notify 85 admin@example.com
notify() {
  local limit="${1:-80}" mailto="${2:-}" out
  out=$( { disk_alert "$limit"; cpu_alert "$limit"; mem_alert "$limit"; } 2>&1 | grep WARNING || true )
  [[ -z "$out" ]] && { echo "All good"; return 0; }
  echo "$out"
  if [[ -n "$mailto" ]] && command -v mail >/dev/null; then
    echo "$out" | mail -s "ALERT on $(hostname)" "$mailto"
  else
    logger -t health-alert "$out"      # goes to the system log
  fi
}

# --- Task 9: log CPU and memory every N seconds --------------
watch_log() {
  local every="${1:-5}" times="${2:-5}" out="${3:-/tmp/usage.csv}"
  [[ -f "$out" ]] || echo "time,cpu_pct,mem_pct,disk_pct" > "$out"
  for (( i = 0; i < times; i++ )); do
    echo "$(date '+%F %T'),$(cpu_used),$(mem_used),$(disk_used /)" | tee -a "$out"
    sleep "$every"
  done
}

usage() {
  cat <<EOF
Usage: $0 <task> [args]
  sysinfo                        basic system details
  disk_alert [limit%]            warn when a disk is too full
  cpu_alert [limit%]             warn when CPU is high
  mem_alert [limit%]             warn when memory is high
  load_alert                     warn when load is above CPU count
  inode_alert [limit%]           warn when inodes are running out
  disk_hogs [dir] [n]            biggest folders
  report [limit%]                full health report
  notify [limit%] [email]        alert by mail or system log
  watch_log [sec] [times] [file] save usage to a CSV file
EOF
}

task="${1:-}"; shift || true
case "$task" in
  sysinfo|disk_alert|cpu_alert|mem_alert|load_alert|inode_alert|disk_hogs|report|notify|watch_log) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
