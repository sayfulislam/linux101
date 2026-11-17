#!/usr/bin/env bash
# ============================================================
# CATEGORY 1: SHELL BASICS
# Topics: variables, arguments, if/else, loops, functions,
#         arrays, exit codes, reading input, error handling
# Usage : ./01_basics.sh <task> [args]
# ============================================================
set -euo pipefail

# --- Task 1: variables and special variables -----------------
vars() {
  local name="DevOps"
  readonly COURSE="Linux"
  echo "Hello, $name. Course: $COURSE"
  echo "Script name : $0"
  echo "Arg count   : $#"
  echo "All args    : $*"
  echo "Script PID  : $$"
  echo "Today       : $(date +%F)"
  echo "Default val : ${UNSET_VAR:-default-value}"
}

# --- Task 2: if / elif / else with number tests --------------
check_number() {
  local n="${1:?give a number}"
  if ! [[ "$n" =~ ^-?[0-9]+$ ]]; then
    echo "Not a number: $n" >&2; return 1
  fi
  if   (( n > 0 )); then echo "$n is positive"
  elif (( n < 0 )); then echo "$n is negative"
  else                   echo "$n is zero"
  fi
  (( n % 2 == 0 )) && echo "$n is even" || echo "$n is odd"
}

# --- Task 3: file tests --------------------------------------
check_path() {
  local p="${1:?give a path}"
  if   [[ -d "$p" ]]; then echo "$p is a directory"
  elif [[ -f "$p" ]]; then echo "$p is a file"
       [[ -r "$p" ]] && echo "  readable"
       [[ -w "$p" ]] && echo "  writable"
       [[ -x "$p" ]] && echo "  executable"
       [[ -s "$p" ]] || echo "  empty file"
  else echo "$p does not exist"; return 1
  fi
}

# --- Task 4: loops (for, while, until) -----------------------
loops() {
  echo "for loop:";   for i in 1 2 3; do echo "  item $i"; done
  echo "C-style:";    for (( i = 0; i < 3; i++ )); do echo "  i=$i"; done
  echo "while loop:"; local c=3; while (( c > 0 )); do echo "  $c"; c=$((c - 1)); done
  echo "until loop:"; local u=0; until (( u >= 3 )); do echo "  $u"; u=$((u + 1)); done
  echo "read a file line by line:"
  while IFS=: read -r user _ uid _; do
    echo "  $user (uid $uid)"
  done < <(head -n 3 /etc/passwd)
}

# --- Task 5: arrays and associative arrays -------------------
arrays() {
  local servers=(web1 web2 db1)
  servers+=(cache1)
  echo "Count : ${#servers[@]}"
  echo "First : ${servers[0]}"
  for s in "${servers[@]}"; do echo "  server: $s"; done

  declare -A ports=([ssh]=22 [http]=80 [https]=443)
  for svc in "${!ports[@]}"; do echo "  $svc -> ${ports[$svc]}"; done
}

# --- Task 6: functions, return codes, case -------------------
calc() {
  local a="${1:?a}" op="${2:?op}" b="${3:?b}"
  case "$op" in
    +) echo $(( a + b )) ;;
    -) echo $(( a - b )) ;;
    x) echo $(( a * b )) ;;
    /) (( b == 0 )) && { echo "Cannot divide by zero" >&2; return 1; }
       echo $(( a / b )) ;;
    *) echo "Unknown operator: $op (use + - x /)" >&2; return 2 ;;
  esac
}

# --- Task 7: factorial and fibonacci (common exam questions) -
factorial() {
  local n="${1:?n}" f=1
  for (( i = 2; i <= n; i++ )); do f=$(( f * i )); done
  echo "$n! = $f"
}
fibonacci() {
  local n="${1:?n}" a=0 b=1
  for (( i = 0; i < n; i++ )); do
    printf '%s ' "$a"; local t=$(( a + b )); a=$b; b=$t
  done; echo
}

# --- Task 8: string work -------------------------------------
strings() {
  local s="${1:-Hello DevOps World}"
  echo "Text      : $s"
  echo "Length    : ${#s}"
  echo "Upper     : ${s^^}"
  echo "Lower     : ${s,,}"
  echo "First 5   : ${s:0:5}"
  echo "Replace   : ${s// /_}"
  echo "Reverse   : $(echo "$s" | rev)"
  local f="/var/log/app/error.log"
  echo "File name : ${f##*/}   Dir: ${f%/*}   Ext: ${f##*.}"
}

# --- Task 9: error handling with trap ------------------------
trap_demo() {
  local tmp; tmp=$(mktemp)
  trap "echo 'Cleaning up $tmp'; rm -f '$tmp'" EXIT
  echo "Working with temp file $tmp"
  echo "data" > "$tmp"
  echo "Done. The trap removes the file when the script ends."
}

usage() {
  cat <<EOF
Usage: $0 <task> [args]
  vars                 show variables and special variables
  check_number <n>     positive/negative, even/odd
  check_path <path>    file or directory tests
  loops                for, while, until
  arrays               arrays and key-value arrays
  calc <a> <op> <b>    calculator (+ - x /)
  factorial <n>        factorial of n
  fibonacci <n>        first n fibonacci numbers
  strings [text]       string operations
  trap_demo            cleanup with trap
EOF
}

task="${1:-}"; shift || true
case "$task" in
  vars|check_number|check_path|loops|arrays|calc|factorial|fibonacci|strings|trap_demo) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
