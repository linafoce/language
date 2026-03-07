#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_PATH="$DEFAULT_REPO_PATH"
DEBOUNCE_SECONDS=15
POLL_SECONDS=2
PID_FILE=""
LOG_FILE=""

usage() {
  cat <<'EOF'
Usage: start-auto-sync.sh [options]
  --repo-path PATH          Git repo path (default: script parent directory)
  --debounce-seconds N      Debounce delay before sync (default: 15)
  --poll-seconds N          Poll interval for file change detection (default: 2)
  --pid-file PATH           PID file path (default: <repo>/logs/auto-sync.pid)
  --log-file PATH           Log path (default: <repo>/logs/auto-sync.log)
  --help                    Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --repo-path)
    REPO_PATH="$2"
    shift 2
    ;;
  --debounce-seconds)
    DEBOUNCE_SECONDS="$2"
    shift 2
    ;;
  --poll-seconds)
    POLL_SECONDS="$2"
    shift 2
    ;;
  --pid-file)
    PID_FILE="$2"
    shift 2
    ;;
  --log-file)
    LOG_FILE="$2"
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

AUTO_SYNC_SCRIPT="$SCRIPT_DIR/auto-sync.sh"
if [[ ! -f "$AUTO_SYNC_SCRIPT" ]]; then
  printf "Cannot find %s\n" "$AUTO_SYNC_SCRIPT" >&2
  exit 1
fi

if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="$REPO_PATH/logs/auto-sync.log"
fi

if [[ -z "$PID_FILE" ]]; then
  PID_FILE="$REPO_PATH/logs/auto-sync.pid"
fi

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$PID_FILE")"

if [[ -f "$PID_FILE" ]]; then
  existing_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ "$existing_pid" =~ ^[0-9]+$ ]] && kill -0 "$existing_pid" 2>/dev/null; then
    printf "Auto sync is already running for %s (pid %s)\n" "$REPO_PATH" "$existing_pid"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

nohup "$AUTO_SYNC_SCRIPT" \
  --repo-path "$REPO_PATH" \
  --debounce-seconds "$DEBOUNCE_SECONDS" \
  --poll-seconds "$POLL_SECONDS" \
  --log-file "$LOG_FILE" \
  >/dev/null 2>&1 &

new_pid=$!
printf '%s\n' "$new_pid" >"$PID_FILE"

printf "Auto sync started in background for %s (pid %s)\n" "$REPO_PATH" "$new_pid"
printf "Log file: %s\n" "$LOG_FILE"
