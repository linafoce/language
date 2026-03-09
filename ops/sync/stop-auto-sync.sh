#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_PATH="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUTO_SYNC_SCRIPT="$SCRIPT_DIR/auto-sync.sh"

REPO_PATH="$DEFAULT_REPO_PATH"
PID_FILE=""

usage() {
  cat <<'EOF'
Usage: stop-auto-sync.sh [options]
  --repo-path PATH          Git repo path (default: script parent directory)
  --pid-file PATH           PID file path (default: <repo>/logs/auto-sync.pid)
  --help                    Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --repo-path)
    REPO_PATH="$2"
    shift 2
    ;;
  --pid-file)
    PID_FILE="$2"
    shift 2
    ;;
  --help)
    usage
    exit 0
    ;;
  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    usage >&2
    exit 1
    ;;
  esac
done

if [[ ! -d "$REPO_PATH" ]]; then
  printf "Repo path not found: %s\n" "$REPO_PATH" >&2
  exit 1
fi
REPO_PATH="$(cd "$REPO_PATH" && pwd)"

if [[ -z "$PID_FILE" ]]; then
  PID_FILE="$REPO_PATH/logs/auto-sync.pid"
fi

stopped=0

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    printf "Stopped auto sync process %s for %s\n" "$pid" "$REPO_PATH"
    stopped=1
  fi
  rm -f "$PID_FILE"
fi

if [[ $stopped -eq 0 ]]; then
  pid_list="$(ps -axo pid=,command= | grep -F -- "$AUTO_SYNC_SCRIPT" | grep -F -- "$REPO_PATH" | grep -v grep | awk '{print $1}' || true)"
  if [[ -n "$pid_list" ]]; then
    while IFS= read -r candidate; do
      if [[ "$candidate" =~ ^[0-9]+$ ]]; then
        kill "$candidate" 2>/dev/null || true
      fi
    done <<<"$pid_list"
    printf "Stopped auto sync process(es) for %s\n" "$REPO_PATH"
    stopped=1
  fi
fi

if [[ $stopped -eq 0 ]]; then
  printf "No auto sync process found for %s\n" "$REPO_PATH"
fi
