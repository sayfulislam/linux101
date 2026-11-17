#!/usr/bin/env bash
# ============================================================
# CATEGORY 6: NETWORKING
# Topics: ping, ports, curl, DNS, SSL, ss, firewall, ssh
# Usage : ./06_networking.sh <task> [args]
# ============================================================
set -euo pipefail

# --- Task 1: ping a list of hosts ----------------------------
# File: one host per line
ping_hosts() {
  local f="${1:?file with hosts}"
  while read -r host; do
    [[ -z "$host" || "$host" == \#* ]] && continue
    if ping -c 1 -W 2 "$host" &>/dev/null; then echo "UP    $host"; else echo "DOWN  $host"; fi
  done < "$f"
}

# --- Task 2: is a port open? (no extra tools needed) ---------
port_check() {
  local host="${1:?host}" port="${2:?port}"
  if timeout 3 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
    echo "OPEN    $host:$port"
  else
    echo "CLOSED  $host:$port"; return 1
  fi
}

# --- Task 3: scan common ports on one host -------------------
port_scan() {
  local host="${1:?host}"; shift
  (( $# )) || set -- 22 25 53 80 443 3306 5432 6379 8080
  for p in "$@"; do port_check "$host" "$p" || true; done
}

# --- Task 4: website health check ----------------------------
url_check() {
  local url="${1:?url}" want="${2:-200}" code time
  read -r code time < <(curl -s -o /dev/null -m 10 -w '%{http_code} %{time_total}\n' "$url" || echo "000 0")
  if [[ "$code" == "$want" ]]; then
    echo "OK    $url  code=$code  time=${time}s"
  else
    echo "FAIL  $url  code=$code (wanted $want)"; return 1
  fi
}

# --- Task 5: check many URLs from a file ---------------------
urls_check() {
  local f="${1:?file with urls}" bad=0
  while read -r url; do
    [[ -z "$url" || "$url" == \#* ]] && continue
    url_check "$url" || bad=$(( bad + 1 ))
  done < "$f"
  echo "Failed: $bad"; (( bad == 0 ))
}

# --- Task 6: wait until a service is ready -------------------
wait_for() {
  local host="${1:?host}" port="${2:?port}" tries="${3:-30}"
  for (( i = 1; i <= tries; i++ )); do
    port_check "$host" "$port" &>/dev/null && { echo "$host:$port is ready after ${i} tries"; return 0; }
    sleep 2
  done
  echo "Gave up waiting for $host:$port" >&2; return 1
}

# --- Task 7: DNS lookup --------------------------------------
dns() {
  local name="${1:?domain}"
  echo "A records  : $(getent ahostsv4 "$name" | awk '{ print $1 }' | sort -u | tr '\n' ' ')"
  command -v dig >/dev/null && {
    echo "MX records : $(dig +short MX "$name" | tr '\n' ' ')"
    echo "NS records : $(dig +short NS "$name" | tr '\n' ' ')"
  }
}

# --- Task 8: days left on an SSL certificate -----------------
ssl_days() {
  local host="${1:?host}" port="${2:-443}" warn="${3:-30}" end days
  end=$(echo | openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null \
        | openssl x509 -noout -enddate | cut -d= -f2)
  [[ -n "$end" ]] || { echo "Could not read certificate from $host:$port" >&2; return 2; }
  days=$(( ( $(date -d "$end" +%s) - $(date +%s) ) / 86400 ))
  if (( days < warn )); then echo "WARNING: $host cert ends in $days days ($end)"; return 1; fi
  echo "OK: $host cert has $days days left ($end)"
}

# --- Task 9: local network details ---------------------------
netinfo() {
  echo "== IP addresses ==";      ip -br addr
  echo "== Default route ==";     ip route | grep default || true
  echo "== DNS servers ==";       grep nameserver /etc/resolv.conf || true
  echo "== Listening ports ==";   ss -ltn | tail -n +2 | awk '{ print $4 }' | sort -u
  echo "== Public IP ==";         curl -s -m 5 https://ifconfig.me || echo "(no internet)"; echo
}

# --- Task 10: run a command on many servers by SSH -----------
ssh_run() {
  local f="${1:?file with hosts}"; shift
  local cmd="${*:?command}"
  while read -r host; do
    [[ -z "$host" || "$host" == \#* ]] && continue
    echo "== $host =="
    ssh -n -o BatchMode=yes -o ConnectTimeout=5 "$host" "$cmd" || echo "  failed on $host"
  done < "$f"
}

# --- Task 11: basic firewall setup (ufw) ---------------------
firewall() {
  command -v ufw >/dev/null || { echo "ufw is not installed" >&2; return 1; }
  ufw default deny incoming
  ufw default allow outgoing
  for p in 22/tcp 80/tcp 443/tcp; do ufw allow "$p"; done
  ufw --force enable
  ufw status verbose
}

usage() {
  cat <<EOF
Usage: $0 <task> [args]
  ping_hosts <file>               ping every host in a file
  port_check <host> <port>        test one port
  port_scan <host> [ports...]     test common ports
  url_check <url> [code]          check a website
  urls_check <file>               check many websites
  wait_for <host> <port> [tries]  wait until a port opens
  dns <domain>                    DNS records
  ssl_days <host> [port] [warn]   days left on SSL certificate
  netinfo                         IP, route, DNS, open ports
  ssh_run <file> <command>        run a command on many servers
  firewall                        simple ufw rules (needs root)
EOF
}

task="${1:-}"; shift || true
case "$task" in
  ping_hosts|port_check|port_scan|url_check|urls_check|wait_for|dns|ssl_days|netinfo|ssh_run|firewall) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
