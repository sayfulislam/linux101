#!/usr/bin/env bash
# ============================================================
# CATEGORY 3: USERS, GROUPS AND PERMISSIONS
# Topics: useradd, usermod, groups, chmod, chown, sudo, SSH keys
# Usage : sudo ./03_users_permissions.sh <task> [args]
# ============================================================
set -euo pipefail

need_root() {
  (( EUID == 0 )) || { echo "Run this task as root (use sudo)" >&2; exit 1; }
}

# --- Task 1: create one user with a home folder --------------
create_user() {
  need_root
  local user="${1:?username}" group="${2:-}"
  if id "$user" &>/dev/null; then
    echo "User $user already exists"; return 0
  fi
  useradd -m -s /bin/bash "$user"
  local pass; pass=$(openssl rand -base64 12)
  echo "$user:$pass" | chpasswd
  chage -d 0 "$user"                       # must change password at first login
  [[ -n "$group" ]] && { getent group "$group" >/dev/null || groupadd "$group"; usermod -aG "$group" "$user"; }
  echo "Created $user  password: $pass"
}

# --- Task 2: create many users from a file -------------------
# File format, one per line:  username,group
bulk_users() {
  need_root
  local f="${1:?file}"
  while IFS=, read -r user group; do
    [[ -z "$user" || "$user" == \#* ]] && continue
    create_user "$user" "$group"
  done < "$f"
}

# --- Task 3: delete or lock a user ---------------------------
delete_user() { need_root; userdel -r "${1:?username}" && echo "Deleted $1"; }
lock_user()   { need_root; usermod -L "${1:?username}" && echo "Locked $1"; }
unlock_user() { need_root; usermod -U "${1:?username}" && echo "Unlocked $1"; }

# --- Task 4: list real (human) users -------------------------
list_users() {
  awk -F: '$3 >= 1000 && $3 < 65534 { printf "%-15s uid=%-6s home=%-20s shell=%s\n", $1, $3, $6, $7 }' /etc/passwd
}

# --- Task 5: user audit --------------------------------------
audit() {
  echo "== Users with UID 0 (should be only root) =="
  awk -F: '$3 == 0 { print $1 }' /etc/passwd
  echo "== Users with no password (needs root) =="
  [[ -r /etc/shadow ]] && awk -F: '$2 == "" { print $1 }' /etc/shadow || echo "(cannot read /etc/shadow)"
  echo "== Users who can use sudo =="
  getent group sudo wheel 2>/dev/null | awk -F: '{ print $1 ": " $4 }'
  echo "== Logged in now =="
  who
  echo "== Last 5 logins =="
  last -n 5 2>/dev/null || true
}

# --- Task 6: set up a shared team folder ---------------------
shared_dir() {
  need_root
  local dir="${1:?dir}" group="${2:?group}"
  getent group "$group" >/dev/null || groupadd "$group"
  mkdir -p "$dir"
  chown root:"$group" "$dir"
  chmod 2770 "$dir"          # 2 = setgid: new files keep the group
  echo "$dir is shared by group $group"; ls -ld "$dir"
}

# --- Task 7: fix permissions for a web folder ----------------
fix_web_perms() {
  need_root
  local dir="${1:?dir}" owner="${2:-www-data}"
  chown -R "$owner":"$owner" "$dir"
  find "$dir" -type d -exec chmod 755 {} +
  find "$dir" -type f -exec chmod 644 {} +
  echo "Folders 755, files 644, owner $owner"
}

# --- Task 8: find risky files --------------------------------
risky_files() {
  local dir="${1:-/}"
  echo "== World-writable files =="
  find "$dir" -xdev -type f -perm -0002 2>/dev/null | head -n 20
  echo "== SUID files =="
  find "$dir" -xdev -type f -perm -4000 2>/dev/null | head -n 20
  echo "== Files with no owner =="
  find "$dir" -xdev -nouser 2>/dev/null | head -n 20
}

# --- Task 9: add an SSH public key for a user ----------------
add_ssh_key() {
  need_root
  local user="${1:?username}" key="${2:?public key text}"
  local home; home=$(getent passwd "$user" | cut -d: -f6)
  install -d -m 700 -o "$user" -g "$user" "$home/.ssh"
  echo "$key" >> "$home/.ssh/authorized_keys"
  chmod 600 "$home/.ssh/authorized_keys"
  chown "$user":"$user" "$home/.ssh/authorized_keys"
  echo "Key added for $user"
}

# --- Task 10: explain a permission number --------------------
explain_perm() {
  local p="${1:?e.g. 754}" who=(owner group others)
  for i in 0 1 2; do
    local d="${p:$i:1}" s=""
    (( d & 4 )) && s+="read "; (( d & 2 )) && s+="write "; (( d & 1 )) && s+="execute "
    echo "${who[$i]}: ${s:-nothing}"
  done
}

usage() {
  cat <<EOF
Usage: sudo $0 <task> [args]
  create_user <name> [group]     create a user
  bulk_users <file>              create users from file (name,group)
  delete_user|lock_user|unlock_user <name>
  list_users                     list human users
  audit                          security check of users
  shared_dir <dir> <group>       team folder with setgid
  fix_web_perms <dir> [owner]    755 folders, 644 files
  risky_files [dir]              world-writable, SUID, no-owner files
  add_ssh_key <user> "<key>"     add SSH public key
  explain_perm <754>             explain a permission number
EOF
}

task="${1:-}"; shift || true
case "$task" in
  create_user|bulk_users|delete_user|lock_user|unlock_user|list_users|audit|shared_dir|fix_web_perms|risky_files|add_ssh_key|explain_perm) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
