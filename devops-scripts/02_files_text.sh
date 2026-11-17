#!/usr/bin/env bash
# ============================================================
# CATEGORY 2: FILES AND TEXT PROCESSING
# Topics: find, grep, sed, awk, sort, uniq, cut, wc, rename
# Usage : ./02_files_text.sh <task> [args]
# ============================================================
set -euo pipefail

# --- Task 1: count lines, words, characters ------------------
count() {
  local f="${1:?file}"
  echo "Lines: $(wc -l < "$f")  Words: $(wc -w < "$f")  Chars: $(wc -m < "$f")"
}

# --- Task 2: find the biggest files in a folder --------------
biggest() {
  local dir="${1:-.}" n="${2:-10}"
  find "$dir" -type f -printf '%s\t%p\n' 2>/dev/null \
    | sort -rn | head -n "$n" \
    | awk -F'\t' '{ printf "%10.2f MB  %s\n", $1/1024/1024, $2 }'
}

# --- Task 3: find files older than N days (and delete) -------
old_files() {
  local dir="${1:?dir}" days="${2:-30}" action="${3:-list}"
  if [[ "$action" == "delete" ]]; then
    find "$dir" -type f -mtime +"$days" -print -delete
  else
    find "$dir" -type f -mtime +"$days" -ls
  fi
}

# --- Task 4: search a word in all files ----------------------
search() {
  local word="${1:?word}" dir="${2:-.}"
  grep -rIn --color=never -- "$word" "$dir" || echo "No match for '$word'"
}

# --- Task 5: replace text in a file (keeps a .bak copy) ------
replace() {
  local old="${1:?old}" new="${2:?new}" f="${3:?file}"
  sed -i.bak "s|${old}|${new}|g" "$f"
  echo "Replaced '$old' with '$new' in $f (backup: $f.bak)"
}

# --- Task 6: word frequency (top N words) --------------------
word_freq() {
  local f="${1:?file}" n="${2:-10}"
  tr -cs '[:alpha:]' '\n' < "$f" | tr '[:upper:]' '[:lower:]' \
    | sort | uniq -c | sort -rn | head -n "$n"
}

# --- Task 7: CSV report with awk -----------------------------
# CSV format: name,department,salary  (first line is the header)
csv_report() {
  local f="${1:?csv file}"
  awk -F, 'NR > 1 {
      sum[$2] += $3; cnt[$2]++; total += $3
      if ($3 > max) { max = $3; top = $1 }
    }
    END {
      printf "%-15s %5s %10s\n", "DEPARTMENT", "COUNT", "AVG"
      for (d in sum) printf "%-15s %5d %10.2f\n", d, cnt[d], sum[d]/cnt[d]
      printf "Total: %d   Highest paid: %s (%d)\n", total, top, max
    }' "$f"
}

# --- Task 8: bulk rename file extension ----------------------
rename_ext() {
  local dir="${1:?dir}" from="${2:?old ext}" to="${3:?new ext}"
  shopt -s nullglob
  for f in "$dir"/*."$from"; do
    mv -v -- "$f" "${f%."$from"}.$to"
  done
}

# --- Task 9: remove duplicate and empty lines ----------------
clean_lines() {
  local f="${1:?file}"
  grep -v '^[[:space:]]*$' "$f" | awk '!seen[$0]++'
}

# --- Task 10: find duplicate files by content ----------------
dup_files() {
  local dir="${1:-.}"
  find "$dir" -type f -exec md5sum {} + | sort | uniq -w32 -D
}

# --- Task 11: handy one-liners -------------------------------
oneliners() {
  local f="${1:-/etc/passwd}"
  echo "Line 5           : $(sed -n '5p' "$f")"
  echo "Users with bash  : $(grep -c 'bash$' "$f" || true)"
  echo "First column     :"; cut -d: -f1 "$f" | head -n 3
  echo "Lines 2 to 4     :"; sed -n '2,4p' "$f"
  echo "Last field (awk) :"; awk -F: '{ print $NF }' "$f" | sort | uniq -c
}

usage() {
  cat <<EOF
Usage: $0 <task> [args]
  count <file>                    lines, words, characters
  biggest [dir] [n]               biggest files
  old_files <dir> [days] [delete] files older than N days
  search <word> [dir]             search text in files
  replace <old> <new> <file>      replace text
  word_freq <file> [n]            most used words
  csv_report <file.csv>           report from name,dept,salary CSV
  rename_ext <dir> <old> <new>    change file extension
  clean_lines <file>              remove empty and repeated lines
  dup_files [dir]                 find duplicate files
  oneliners [file]                useful one-line commands
EOF
}

task="${1:-}"; shift || true
case "$task" in
  count|biggest|old_files|search|replace|word_freq|csv_report|rename_ext|clean_lines|dup_files|oneliners) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
