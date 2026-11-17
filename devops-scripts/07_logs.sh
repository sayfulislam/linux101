#!/usr/bin/env bash
# ============================================================
# CATEGORY 7: LOG ANALYSIS AND LOG ROTATION
# Topics: grep, awk, sort, uniq on logs; rotate; failed logins
# Usage : ./07_logs.sh <task> [args]
# Access log format: standard nginx / apache "combined" format
# ============================================================
set -euo pipefail

# --- Task 1: count ERROR, WARN, INFO lines -------------------
levels() {
  local f="${1:?log file}"
  for lvl in ERROR WARN INFO DEBUG; do
    printf '%-6s %s\n' "$lvl" "$(grep -c -w "$lvl" "$f" || true)"
  done
}

# --- Task 2: most common error messages ----------------------
top_errors() {
  local f="${1:?log file}" n="${2:-10}"
  grep -w ERROR "$f" | sed -E 's/^.*ERROR[: ]*//; s/[0-9]+/N/g' \
    | sort | uniq -c | sort -rn | head -n "$n"
}

# --- Task 3: top IP addresses in an access log ---------------
top_ips() {
  local f="${1:?access log}" n="${2:-10}"
  awk '{ print $1 }' "$f" | sort | uniq -c | sort -rn | head -n "$n"
}

# --- Task 4: count of each HTTP status code ------------------
status_codes() {
  local f="${1:?access log}"
  awk '{ print $9 }' "$f" | grep -E '^[0-9]{3}$' | sort | uniq -c | sort -rn
}

# --- Task 5: most requested pages and all 404 pages ----------
top_urls() { awk '{ print $7 }' "${1:?access log}" | sort | uniq -c | sort -rn | head -n "${2:-10}"; }
not_found() { awk '$9 == 404 { print $7 }' "${1:?access log}" | sort | uniq -c | sort -rn | head -n "${2:-10}"; }

# --- Task 6: requests per hour -------------------------------
per_hour() {
  awk -F'[:[]' '{ print $2 " " $3 ":00" }' "${1:?access log}" | sort | uniq -c
}

# --- Task 7: full access log summary -------------------------
summary() {
  local f="${1:?access log}"
  awk '{ total++; ips[$1]++; bytes += $10
         if ($9 >= 500) e5++; else if ($9 >= 400) e4++ }
       END {
         printf "Requests      : %d\n", total
         printf "Unique IPs    : %d\n", length(ips)
         printf "4xx errors    : %d\n", e4
         printf "5xx errors    : %d (%.2f%%)\n", e5, total ? e5 * 100 / total : 0
         printf "Data sent     : %.2f MB\n", bytes / 1024 / 1024
       }' "$f"
}

# --- Task 8: failed SSH logins -------------------------------
failed_ssh() {
  local f="${1:-/var/log/auth.log}" n="${2:-10}"
  [[ -r "$f" ]] || f=/var/log/secure
  [[ -r "$f" ]] || { echo "Cannot read auth log (try sudo)" >&2; return 1; }
  echo "Failed logins by IP:"
  grep 'Failed password' "$f" | grep -oE 'from [0-9.]+' | awk '{ print $2 }' \
    | sort | uniq -c | sort -rn | head -n "$n"
}

# --- Task 9: show log lines between two times ----------------
# Example: between app.log "2026-01-10 10:00" "2026-01-10 11:00"
between() {
  local f="${1:?log file}" from="${2:?from}" to="${3:?to}"
  awk -v a="$from" -v b="$to" '{ t = substr($0, 1, length(a)) } t >= a && t <= b' "$f"
}

# --- Task 10: watch a log and alert on a word ----------------
watch_word() {
  local f="${1:?log file}" word="${2:-ERROR}"
  echo "Watching $f for '$word' (Ctrl+C to stop)"
  tail -Fn0 "$f" | while read -r line; do
    [[ "$line" == *"$word"* ]] && echo "ALERT $(date '+%T'): $line"
  done
}

# --- Task 11: simple log rotation ----------------------------
rotate() {
  local f="${1:?log file}" keep="${2:-5}" max_mb="${3:-10}"
  [[ -f "$f" ]] || { echo "No such file: $f" >&2; return 1; }
  local size_mb=$(( $(stat -c %s "$f") / 1024 / 1024 ))
  (( size_mb < max_mb )) && { echo "$f is ${size_mb}MB, under ${max_mb}MB - nothing to do"; return 0; }
  local stamp; stamp=$(date +%Y%m%d_%H%M%S)
  cp "$f" "$f.$stamp" && : > "$f"          # copy then empty, so the app keeps writing
  gzip "$f.$stamp"
  ls -1t "$f".*.gz 2>/dev/null | tail -n +"$(( keep + 1 ))" | xargs -r rm -f
  echo "Rotated $f -> $f.$stamp.gz (keeping last $keep)"
}

# --- Task 12: make a logrotate config ------------------------
logrotate_conf() {
  local path="${1:?log path, e.g. /var/log/myapp/*.log}" name="${2:-myapp}"
  cat <<EOF
# Save as /etc/logrotate.d/$name
$path {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
}

# --- make sample logs to practice with -----------------------
sample() {
  local dir="${1:-/tmp/samplelogs}"; mkdir -p "$dir"
  local ips=(10.0.0.1 10.0.0.2 192.168.1.5 172.16.0.9) urls=(/ /login /api/users /img/a.png /missing)
  local codes=(200 200 200 301 404 500) lv=(INFO INFO WARN ERROR DEBUG) msg=("db timeout" "user login" "disk slow" "cache miss")
  : > "$dir/access.log"; : > "$dir/app.log"
  for i in $(seq 1 200); do
    printf '%s - - [10/Jan/2026:%02d:%02d:00 +0000] "GET %s HTTP/1.1" %s %d "-" "curl"\n' \
      "${ips[RANDOM % 4]}" $(( RANDOM % 24 )) $(( RANDOM % 60 )) "${urls[RANDOM % 5]}" "${codes[RANDOM % 6]}" $(( RANDOM % 5000 )) >> "$dir/access.log"
    printf '2026-01-10 %02d:%02d:00 %s %s id=%d\n' $(( RANDOM % 24 )) $(( RANDOM % 60 )) "${lv[RANDOM % 5]}" "${msg[RANDOM % 4]}" "$i" >> "$dir/app.log"
  done
  sort -o "$dir/app.log" "$dir/app.log"
  echo "Made $dir/access.log and $dir/app.log"
}

usage() {
  cat <<EOF
Usage: $0 <task> [args]
  sample [dir]                      make sample logs to practice
  levels <log>                      count ERROR/WARN/INFO
  top_errors <log> [n]              most common errors
  top_ips <access.log> [n]          busiest IP addresses
  status_codes <access.log>         HTTP status code counts
  top_urls | not_found <access.log> popular pages / 404 pages
  per_hour <access.log>             requests per hour
  summary <access.log>              full summary
  failed_ssh [auth.log] [n]         failed SSH logins by IP
  between <log> "<from>" "<to>"     lines between two times
  watch_word <log> [word]           live alert on a word
  rotate <log> [keep] [max_mb]      rotate and compress a log
  logrotate_conf <path> [name]      print a logrotate config
EOF
}

task="${1:-}"; shift || true
case "$task" in
  sample|levels|top_errors|top_ips|status_codes|top_urls|not_found|per_hour|summary|failed_ssh|between|watch_word|rotate|logrotate_conf) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
