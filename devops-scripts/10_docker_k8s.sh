#!/usr/bin/env bash
# ============================================================
# CATEGORY 10: DOCKER AND KUBERNETES
# Topics: build, run, cleanup, health, logs, kubectl checks
# Usage : ./10_docker_k8s.sh <task> [args]
# ============================================================
set -euo pipefail

need() { command -v "$1" >/dev/null || { echo "$1 is not installed" >&2; exit 1; }; }

# ======================= DOCKER ==============================

# --- Task 1: build and tag an image --------------------------
d_build() {
  need docker
  local name="${1:?image name}" dir="${2:-.}" tag
  tag=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M)
  docker build -t "$name:$tag" -t "$name:latest" "$dir"
  echo "Built $name:$tag and $name:latest"
}

# --- Task 2: build and push to a registry --------------------
d_push() {
  need docker
  local name="${1:?image name}" registry="${2:?registry, e.g. myreg.azurecr.io}" tag="${3:-latest}"
  docker tag "$name:$tag" "$registry/$name:$tag"
  docker push "$registry/$name:$tag"
}

# --- Task 3: replace a running container with a new one ------
d_redeploy() {
  need docker
  local cname="${1:?container name}" image="${2:?image}" ports="${3:-80:80}"
  docker pull "$image" || true
  docker rm -f "$cname" 2>/dev/null || true
  docker run -d --name "$cname" --restart unless-stopped -p "$ports" "$image"
  docker ps --filter "name=^${cname}$"
}

# --- Task 4: container status and restart if stopped ---------
d_watch() {
  need docker
  local cname="${1:?container name}" state
  state=$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null || echo missing)
  if [[ "$state" == "running" ]]; then
    echo "OK: $cname is running"
  elif [[ "$state" == "missing" ]]; then
    echo "ERROR: no container named $cname"; return 1
  else
    echo "$cname is $state - starting it"; docker start "$cname"
  fi
}

# --- Task 5: clean up unused Docker data ---------------------
d_cleanup() {
  need docker
  echo "Before:"; docker system df
  docker container prune -f
  docker image prune -af --filter "until=${1:-168h}"   # older than 7 days
  docker volume prune -f
  docker network prune -f
  echo "After:";  docker system df
}

# --- Task 6: resource use and unhealthy containers -----------
d_stats() {
  need docker
  docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'
  echo "Not healthy / stopped:"
  docker ps -a --filter health=unhealthy --filter status=exited --format '  {{.Names}}  {{.Status}}'
}

# --- Task 7: count errors in container logs ------------------
d_logs_errors() {
  need docker
  local cname="${1:?container name}" since="${2:-1h}"
  local n; n=$(docker logs --since "$since" "$cname" 2>&1 | grep -ciE 'error|exception|fatal' || true)
  echo "$cname: $n error lines in the last $since"
  docker logs --since "$since" "$cname" 2>&1 | grep -iE 'error|exception|fatal' | tail -n 5 || true
}

# --- Task 8: backup a Docker volume --------------------------
d_volume_backup() {
  need docker
  local vol="${1:?volume name}" dest="${2:-$PWD}"
  local file; file="${vol}_$(date +%Y%m%d_%H%M%S).tar.gz"
  docker run --rm -v "$vol":/data:ro -v "$dest":/backup alpine tar -czf "/backup/$file" -C /data .
  echo "Saved $dest/$file"
}

# --- Task 9: docker compose update ---------------------------
d_compose_update() {
  need docker
  local dir="${1:-.}"
  ( cd "$dir" && docker compose pull && docker compose up -d --remove-orphans && docker compose ps )
}

# ===================== KUBERNETES ============================

# --- Task 10: pods that are not healthy ----------------------
k_bad_pods() {
  need kubectl
  kubectl get pods -A --no-headers | awk '$4 != "Running" && $4 != "Completed"' || true
  echo "Pods with many restarts (5 or more):"
  kubectl get pods -A --no-headers | awk '$5 + 0 >= 5 { print "  " $1 "/" $2 " restarts=" $5 }'
}

# --- Task 11: cluster summary --------------------------------
k_summary() {
  need kubectl
  echo "Context : $(kubectl config current-context)"
  echo "Nodes   :"; kubectl get nodes --no-headers | awk '{ print "  " $1 " " $2 }'
  echo "Pods by status:"; kubectl get pods -A --no-headers | awk '{ print $4 }' | sort | uniq -c
  kubectl top nodes 2>/dev/null || echo "(metrics-server not installed)"
}

# --- Task 12: deploy a new image and roll back if it fails ---
k_deploy() {
  need kubectl
  local deploy="${1:?deployment}" image="${2:?image}" ns="${3:-default}" container="${4:-$1}"
  kubectl -n "$ns" set image "deployment/$deploy" "$container=$image"
  if kubectl -n "$ns" rollout status "deployment/$deploy" --timeout=120s; then
    echo "Deploy OK"
  else
    echo "Deploy failed - rolling back"
    kubectl -n "$ns" rollout undo "deployment/$deploy"; return 1
  fi
}

# --- Task 13: restart, scale and debug helpers ---------------
k_restart() { need kubectl; kubectl -n "${2:-default}" rollout restart "deployment/${1:?deployment}"; }
k_scale()   { need kubectl; kubectl -n "${3:-default}" scale "deployment/${1:?deployment}" --replicas="${2:?count}"; }
k_debug() {
  need kubectl
  local pod="${1:?pod}" ns="${2:-default}"
  kubectl -n "$ns" describe pod "$pod" | sed -n '/Events:/,$p'
  echo "--- last 20 log lines ---"
  kubectl -n "$ns" logs "$pod" --tail=20 --all-containers || kubectl -n "$ns" logs "$pod" --previous --tail=20
}

# --- Task 14: backup all objects in a namespace --------------
k_backup() {
  need kubectl
  local ns="${1:-default}" out="${2:-./k8s-backup}"
  mkdir -p "$out"
  for kind in deployment service configmap ingress; do
    kubectl -n "$ns" get "$kind" -o yaml > "$out/${ns}_${kind}.yaml" 2>/dev/null || true
  done
  echo "Saved YAML files in $out"
}

usage() {
  cat <<EOF
Usage: $0 <task> [args]
 Docker:
  d_build <name> [dir]                build image, tag with git hash
  d_push <name> <registry> [tag]      tag and push
  d_redeploy <cname> <image> [ports]  replace running container
  d_watch <cname>                     start container if stopped
  d_cleanup [age]                     remove unused data
  d_stats                             CPU / memory per container
  d_logs_errors <cname> [since]       count errors in logs
  d_volume_backup <volume> [dest]     backup a volume
  d_compose_update [dir]              pull and restart compose app
 Kubernetes:
  k_bad_pods                          pods not running / restarting
  k_summary                           nodes and pod counts
  k_deploy <deploy> <image> [ns] [container]  update + auto rollback
  k_restart <deploy> [ns]             restart a deployment
  k_scale <deploy> <count> [ns]       change replica count
  k_debug <pod> [ns]                  events and logs of a pod
  k_backup [ns] [outdir]              save YAML of a namespace
EOF
}

task="${1:-}"; shift || true
case "$task" in
  d_build|d_push|d_redeploy|d_watch|d_cleanup|d_stats|d_logs_errors|d_volume_backup|d_compose_update|k_bad_pods|k_summary|k_deploy|k_restart|k_scale|k_debug|k_backup) "$task" "$@" ;;
  *) usage; exit 1 ;;
esac
