#!/usr/bin/env bash
# ============================================================
# CATEGORY 9: GIT AND CI/CD
# Topics: git automation, version tags, build-test-deploy,
#         rollback, environment files, package install
# Usage : ./09_git_cicd.sh <task> [args]
# ============================================================
set -euo pipefail

log()  { echo "[$(date '+%T')] $*"; }
fail() { echo "[$(date '+%T')] ERROR: $*" >&2; exit 1; }

# --- Task 1: add, commit and push in one step ----------------
quick_push() {
  local msg="${1:?commit message}" branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  git add -A
  git diff --cached --quiet && { log "Nothing to commit"; return 0; }
  git commit -m "$msg"
  git push origin "$branch"
  log "Pushed to $branch"
}

# --- Task 2: repo summary ------------------------------------
repo_info() {
  echo "Branch      : $(git rev-parse --abbrev-ref HEAD)"
  echo "Last commit : $(git log -1 --pretty='%h %s (%an, %ar)')"
  echo "Commits     : $(git rev-list --count HEAD)"
  echo "Changed     : $(git status --porcelain | wc -l) files"
  echo "Top authors :"; git shortlog -sn HEAD | head -n 5
}

# --- Task 3: delete local branches already merged ------------
clean_branches() {
  local main="${1:-main}"
  git branch --merged "$main" | grep -vE "^\*|^\s*($main|master|develop)$" | xargs -r git branch -d
}

# --- Task 4: make the next version tag (v1.2.3) --------------
bump_version() {
  local part="${1:-patch}" last major minor patch
  last=$(git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)
  IFS=. read -r major minor patch <<< "${last#v}"
  case "$part" in
    major) major=$(( major + 1 )); minor=0; patch=0 ;;
    minor) minor=$(( minor + 1 )); patch=0 ;;
    patch) patch=$(( patch + 1 )) ;;
    *) fail "use major, minor or patch" ;;
  esac
  local new="v$major.$minor.$patch"
  git tag -a "$new" -m "Release $new"
  log "$last -> $new   (run: git push origin $new)"
}

# --- Task 5: update many repos under one folder --------------
pull_all() {
  local base="${1:-.}"
  for d in "$base"/*/.git; do
    [[ -d "$d" ]] || continue
    local repo="${d%/.git}"
    echo "== $repo =="; git -C "$repo" pull --ff-only || echo "  pull failed"
  done
}

# --- Task 6: pre-commit hook (block secrets and bad scripts) -
install_hook() {
  local hook=".git/hooks/pre-commit"
  cat > "$hook" <<'EOF'
#!/usr/bin/env bash
# Stops the commit if a secret or a broken shell script is found.
if git diff --cached | grep -E '^\+' | grep -qiE '(password|secret|api_key|token)\s*[=:]\s*["'"'"'][^"'"'"']+'; then
  echo "Commit blocked: looks like a password or key in your changes"; exit 1
fi
for f in $(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$'); do
  bash -n "$f" || { echo "Commit blocked: syntax error in $f"; exit 1; }
done
EOF
  chmod +x "$hook"; log "Hook installed at $hook"
}

# --- Task 7: simple pipeline: check -> build -> test -> pack -
pipeline() {
  local app="${1:-app}" out="${2:-./dist}" start=$SECONDS
  stage() { log "===== STAGE: $1 ====="; }

  stage "check tools"
  for t in git tar; do command -v "$t" >/dev/null || fail "$t is missing"; done

  stage "lint shell scripts"
  while IFS= read -r f; do bash -n "$f" || fail "syntax error in $f"; done < <(find . -name '*.sh' -not -path './.git/*')

  stage "build"
  [[ -f Makefile ]]     && make build
  [[ -f package.json ]] && npm ci && npm run build --if-present

  stage "test"
  [[ -f Makefile ]]     && make test
  [[ -f package.json ]] && npm test --if-present

  stage "package"
  mkdir -p "$out"
  local ver; ver=$(git rev-parse --short HEAD 2>/dev/null || date +%s)
  tar -czf "$out/${app}_${ver}.tar.gz" --exclude=.git --exclude="$out" .
  log "Artifact: $out/${app}_${ver}.tar.gz"
  log "Pipeline passed in $(( SECONDS - start ))s"
}

# --- Task 8: deploy with releases folder and symlink ---------
# Layout: /opt/app/releases/<time>   /opt/app/current -> newest release
deploy() {
  local artifact="${1:?artifact.tar.gz}" base="${2:-/opt/app}" keep="${3:-5}"
  local rel; rel="$base/releases/$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$rel"
  tar -xzf "$artifact" -C "$rel"
  ln -sfn "$rel" "$base/current"                 # switch to the new version
  log "Now live: $rel"
  ls -1d "$base"/releases/*/ | sort -r | tail -n +"$(( keep + 1 ))" | xargs -r rm -rf
}

# --- Task 9: rollback to the release before ------------------
rollback() {
  local base="${1:-/opt/app}" prev
  local now; now=$(readlink -f "$base/current")
  prev=$(ls -1d "$base"/releases/*/ | sort -r | sed 's|/$||' | awk -v c="$now" 'found { print; exit } $0 == c { found = 1 }')
  [[ -n "$prev" ]] || fail "no older release to go back to"
  ln -sfn "$prev" "$base/current"
  log "Rolled back to $prev"
}

# --- Task 10: deploy, health check, auto rollback ------------
safe_deploy() {
  local artifact="${1:?artifact}" url="${2:?health url}" base="${3:-/opt/app}"
  deploy "$artifact" "$base"
  for i in 1 2 3 4 5; do
    [[ "$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" || true)" == "200" ]] && { log "Health check passed"; return 0; }
    sleep 3
  done
  log "Health check failed, rolling back"; rollback "$base"; return 1
}

# --- Task 11: check that needed env variables are set --------
check_env() {
  local missing=0
  for v in "$@"; do
    [[ -n "${!v:-}" ]] || { echo "Missing: $v"; missing=1; }
  done
  (( missing == 0 )) && echo "All variables are set"
  return "$missing"
}

# --- Task 12: install packages on any Linux ------------------
install_pkgs() {
  (( $# )) || fail "give package names"
  if   command -v apt-get >/dev/null; then apt-get update -y && apt-get install -y "$@"
  elif command -v dnf     >/dev/null; then dnf install -y "$@"
  elif command -v yum     >/dev/null; then yum install -y "$@"
  else fail "no known package manager"
  fi
}

usage() {
  cat <<EOF
Usage: $0 <task> [args]
  quick_push "<message>"            add + commit + push
  repo_info                         repo summary
  clean_branches [main]             delete merged branches
  bump_version [major|minor|patch]  make next version tag
  pull_all [dir]                    git pull in all repos
  install_hook                      pre-commit hook
  pipeline [app] [outdir]           check, build, test, package
  deploy <artifact> [base] [keep]   deploy with symlink switch
  rollback [base]                   go back one release
  safe_deploy <artifact> <url> [base] deploy + health check + rollback
  check_env VAR1 VAR2 ...           check needed variables
  install_pkgs pkg1 pkg2 ...        install on apt/dnf/yum
EOF
}

task="${1:-}"; shift || true
case "$task" in
  quick_push|repo_info|clean_branches|bump_version|pull_all|install_hook|pipeline|deploy|rollback|safe_deploy|check_env|install_pkgs) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
