#!/usr/bin/env bash
# ============================================================
# CATEGORY 4: PROCESSES AND SERVICES
# Topics: ps, kill, top, nice, systemctl, journalctl, systemd unit
# Usage : ./04_processes_services.sh <task> [args]
# ============================================================
set -euo pipefail

# --- Task 1: top processes by CPU or memory ------------------
top_cpu() { ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -n "$(( ${1:-5} + 1 ))"; }
top_mem() { ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | head -n "$(( ${1:-5} + 1 ))"; }

# --- Task 2: is a process running? ---------------------------
is_running() {
  local name="${1:?process name}"
  if pgrep -x "$name" >/dev/null; then
    echo "$name is running (PID: $(pgrep -x "$name" | tr '\n' ' '))"
  else
    echo "$name is NOT running"; return 1
  fi
}

# --- Task 3: stop a process safely (TERM first, then KILL) ---
kill_proc() {
  local name="${1:?process name}" wait="${2:-10}"
  pgrep -x "$name" >/dev/null || { echo "$name is not running"; return 0; }
  pkill -TERM -x "$name"
  for (( i = 0; i < wait; i++ )); do
    pgrep -x "$name" >/dev/null || { echo "$name stopped cleanly"; return 0; }
    sleep 1
  done
  pkill -KILL -x "$name" && echo "$name was force killed"
}

# --- Task 4: find and show zombie processes ------------------
zombies() {
  local z; z=$(ps -eo pid,ppid,stat,comm | awk '$3 ~ /^Z/')
  [[ -n "$z" ]] && { echo "PID PPID STAT CMD"; echo "$z"; } || echo "No zombie processes"
}

# --- Task 5: which process uses a port? ----------------------
port_owner() {
  local port="${1:?port}"
  ss -ltnp 2>/dev/null | awk -v p=":$port" '$4 ~ p"$"' || true
}

# --- Task 6: check a service and restart it if down ----------
# Good for cron:  */5 * * * * /path/04_processes_services.sh watch_service nginx
watch_service() {
  local svc="${1:?service}" log="${2:-/tmp/service_watch.log}"
  if systemctl is-active --quiet "$svc"; then
    echo "$(date '+%F %T') OK   $svc is running" | tee -a "$log"
  else
    echo "$(date '+%F %T') DOWN $svc - restarting" | tee -a "$log"
    systemctl restart "$svc"
    sleep 2
    systemctl is-active --quiet "$svc" \
      && echo "$(date '+%F %T') OK   $svc restarted" | tee -a "$log" \
      || { echo "$(date '+%F %T') FAIL $svc did not start" | tee -a "$log"; return 1; }
  fi
}

# --- Task 7: status of many services -------------------------
services_status() {
  (( $# )) || set -- ssh cron nginx docker
  for s in "$@"; do
    printf '%-12s active=%-9s enabled=%s\n' "$s" \
      "$(systemctl is-active "$s" 2>/dev/null || true)" \
      "$(systemctl is-enabled "$s" 2>/dev/null || echo unknown)"
  done
}

# --- Task 8: list failed services and their last logs --------
failed() {
  systemctl --failed --no-legend --plain | awk '{ print $1 }' | while read -r unit; do
    echo "== $unit =="; journalctl -u "$unit" -n 5 --no-pager
  done
}

# --- Task 9: create a systemd service for a script -----------
make_service() {
  local name="${1:?service name}" cmd="${2:?full command}" user="${3:-root}"
  local unit="/etc/systemd/system/${name}.service"
  cat > "$unit" <<EOF
[Unit]
Description=$name service
After=network.target

[Service]
Type=simple
User=$user
ExecStart=$cmd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now "$name"
  systemctl status "$name" --no-pager | head -n 5
}

# --- Task 10: run a job in the background and wait -----------
bg_jobs() {
  echo "Starting 3 background jobs..."
  local pids=()
  for i in 1 2 3; do ( sleep "$i"; echo "  job $i done" ) & pids+=($!); done
  for p in "${pids[@]}"; do wait "$p"; done
  echo "All jobs finished"
}

usage() {
  cat <<EOF
Usage: $0 <task> [args]
  top_cpu [n] | top_mem [n]         heaviest processes
  is_running <name>                 check a process
  kill_proc <name> [seconds]        stop a process safely
  zombies                           list zombie processes
  port_owner <port>                 who listens on a port
  watch_service <svc> [logfile]     restart service if it is down
  services_status [svc...]          status of services
  failed                            failed services with logs
  make_service <name> "<cmd>" [user] create a systemd service
  bg_jobs                           background jobs and wait
EOF
}

task="${1:-}"; shift || true
case "$task" in
  top_cpu|top_mem|is_running|kill_proc|zombies|port_owner|watch_service|services_status|failed|make_service|bg_jobs) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
