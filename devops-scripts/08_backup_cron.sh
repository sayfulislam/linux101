#!/usr/bin/env bash
# ============================================================
# CATEGORY 8: BACKUP, RESTORE AND SCHEDULING
# Topics: tar, rsync, database dump, retention, cron, lock file
# Usage : ./08_backup_cron.sh <task> [args]
# ============================================================
set -euo pipefail

log() { echo "$(date '+%F %T') $*"; }

# --- Task 1: backup a folder with a date in the name ---------
backup() {
  local src="${1:?source dir}" dest="${2:?backup dir}" keep="${3:-7}"
  [[ -d "$src" ]] || { log "ERROR: $src not found" >&2; return 1; }
  mkdir -p "$dest"
  local name; name="$(basename "$src")_$(date +%Y%m%d_%H%M%S).tar.gz"
  tar -czf "$dest/$name" -C "$(dirname "$src")" "$(basename "$src")"
  tar -tzf "$dest/$name" >/dev/null            # test that the file is good
  sha256sum "$dest/$name" > "$dest/$name.sha256"
  log "Backup done: $dest/$name ($(du -h "$dest/$name" | cut -f1))"
  cleanup "$dest" "$keep"
}

# --- Task 2: delete backups older than N days ----------------
cleanup() {
  local dest="${1:?backup dir}" days="${2:-7}"
  find "$dest" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.sha256' -o -name '*.sql.gz' \) \
    -mtime +"$days" -print -delete | sed 's/^/Removed old: /'
}

# --- Task 3: restore a backup --------------------------------
restore() {
  local file="${1:?backup file}" target="${2:?restore dir}"
  [[ -f "$file.sha256" ]] && ( cd "$(dirname "$file")" && sha256sum -c "$(basename "$file").sha256" )
  mkdir -p "$target"
  tar -xzf "$file" -C "$target"
  log "Restored $file into $target"
}

# --- Task 4: incremental backup (only changed files) ---------
incremental() {
  local src="${1:?source dir}" dest="${2:?backup dir}"
  mkdir -p "$dest"
  local snap="$dest/.snapshot" level="incr"
  [[ -f "$snap" ]] || level="full"
  tar -czf "$dest/${level}_$(date +%Y%m%d_%H%M%S).tar.gz" --listed-incremental="$snap" \
      -C "$(dirname "$src")" "$(basename "$src")"
  log "$level backup saved in $dest"
}

# --- Task 5: sync a folder to another place (local or remote)
sync_dir() {
  local src="${1:?source}" dest="${2:?dest, e.g. user@host:/backup/}"
  rsync -avz --delete "$src" "$dest"
}

# --- Task 6: database backup ---------------------------------
# Password comes from ~/.my.cnf or PGPASSWORD, never from the command line.
db_backup() {
  local type="${1:?mysql|postgres}" db="${2:?database}" dest="${3:-/var/backups/db}"
  mkdir -p "$dest"
  local out; out="$dest/${db}_$(date +%Y%m%d_%H%M%S).sql.gz"
  case "$type" in
    mysql)    mysqldump --single-transaction "$db" | gzip > "$out" ;;
    postgres) pg_dump "$db" | gzip > "$out" ;;
    *) echo "Type must be mysql or postgres" >&2; return 1 ;;
  esac
  log "Database backup: $out"
}

# --- Task 7: run only one copy at a time (lock file) ---------
with_lock() {
  local lock="/tmp/$(basename "$0").lock"
  exec 9> "$lock"
  flock -n 9 || { log "Another copy is already running"; return 1; }
  log "Got the lock, running: $*"
  "$@"
}

# --- Task 8: retry a command that may fail -------------------
retry() {
  local tries="${1:?tries}" delay="${2:?seconds}"; shift 2
  for (( i = 1; i <= tries; i++ )); do
    "$@" && return 0
    log "Try $i/$tries failed"; (( i < tries )) && sleep "$delay"
  done
  return 1
}

# --- Task 9: add a cron job (no duplicates) ------------------
# Example: add_cron "0 2 * * *" "/opt/08_backup_cron.sh backup /var/www /backup >> /var/log/backup.log 2>&1"
add_cron() {
  local when="${1:?schedule}" cmd="${2:?command}"
  local line="$when $cmd"
  if crontab -l 2>/dev/null | grep -Fqx "$line"; then
    echo "Cron job already there"
  else
    ( crontab -l 2>/dev/null; echo "$line" ) | crontab -
    echo "Added: $line"
  fi
}
list_cron()   { crontab -l 2>/dev/null || echo "No cron jobs for $(whoami)"; }
remove_cron() { crontab -l 2>/dev/null | grep -Fv "${1:?text to match}" | crontab -; echo "Removed jobs matching: $1"; }

# --- Task 10: cron time format help --------------------------
cron_help() {
  cat <<'EOF'
 ┌──── minute        (0-59)
 │ ┌── hour          (0-23)
 │ │ ┌ day of month  (1-31)
 │ │ │ ┌ month       (1-12)
 │ │ │ │ ┌ day of week (0-6, 0 = Sunday)
 * * * * *  command

 */5 * * * *     every 5 minutes
 0 * * * *       every hour
 0 2 * * *       every day at 02:00
 30 1 * * 0      every Sunday at 01:30
 0 9 * * 1-5     Monday to Friday at 09:00
 0 0 1 * *       first day of every month
 @reboot         when the server starts
EOF
}

usage() {
  cat <<EOF
Usage: $0 <task> [args]
  backup <src> <dest> [keep_days]     tar.gz backup with date
  cleanup <dest> [days]               remove old backups
  restore <file> <target>             restore a backup
  incremental <src> <dest>            backup only changed files
  sync_dir <src> <dest>               rsync copy
  db_backup <mysql|postgres> <db> [dest]
  with_lock <command...>              run only one copy at a time
  retry <tries> <seconds> <command...>
  add_cron "<schedule>" "<command>"   add a cron job
  list_cron | remove_cron "<text>"
  cron_help                           cron time format
EOF
}

task="${1:-}"; shift || true
case "$task" in
  backup|cleanup|restore|incremental|sync_dir|db_backup|with_lock|retry|add_cron|list_cron|remove_cron|cron_help) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
