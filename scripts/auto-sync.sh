#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_PATH="$DEFAULT_REPO_PATH"
DEBOUNCE_SECONDS=15
POLL_SECONDS=2
WATCH_FOLDERS=("inbox" "courses" "topics")
LOG_FILE=""
RUN_ONCE=0

IS_SYNCING=0
STOPPED=0
GIT_LAST_EXIT=0
GIT_LAST_OUTPUT=""

usage() {
  cat <<'EOF'
Usage: auto-sync.sh [options]
  --repo-path PATH          Git repo path (default: script parent directory)
  --debounce-seconds N      Debounce delay before sync (default: 15)
  --poll-seconds N          Poll interval for file change detection (default: 2)
  --watch-folders LIST      Comma separated folders (default: inbox,courses,topics)
  --log-file PATH           Log path (default: <repo>/logs/auto-sync.log)
  --run-once                Run one sync and exit
  --help                    Show help
EOF
}

trim_line() {
  printf '%s' "$1" | tr -d '\r' | head -n 1
}

is_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

write_log() {
  local level="$1"
  local message="$2"
  local line
  line="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s\n' "$line" >>"$LOG_FILE"
  printf '%s\n' "$line"
}

run_git() {
  local allow_fail="${1:-strict}"
  shift

  if GIT_LAST_OUTPUT="$(git -C "$REPO_PATH" "$@" 2>&1)"; then
    GIT_LAST_EXIT=0
  else
    GIT_LAST_EXIT=$?
  fi

  if [[ $GIT_LAST_EXIT -ne 0 && "$allow_fail" != "allow_fail" ]]; then
    write_log "ERROR" "git $* failed with exit code $GIT_LAST_EXIT. $GIT_LAST_OUTPUT"
    return $GIT_LAST_EXIT
  fi

  return 0
}

test_git_repository() {
  if ! command -v git >/dev/null 2>&1; then
    write_log "ERROR" "Git is not installed or not in PATH."
    return 1
  fi

  if [[ ! -d "$REPO_PATH/.git" ]]; then
    write_log "ERROR" "Path '$REPO_PATH' is not a Git repository."
    return 1
  fi

  run_git allow_fail rev-parse --is-inside-work-tree
  if [[ $GIT_LAST_EXIT -ne 0 ]]; then
    write_log "ERROR" "Path '$REPO_PATH' is not a Git repository."
    return 1
  fi

  return 0
}

get_current_branch() {
  run_git allow_fail symbolic-ref --short HEAD
  if [[ $GIT_LAST_EXIT -eq 0 ]]; then
    local branch
    branch="$(trim_line "$GIT_LAST_OUTPUT")"
    if [[ -n "$branch" ]]; then
      printf '%s' "$branch"
      return 0
    fi
  fi

  run_git allow_fail rev-parse --abbrev-ref HEAD
  if [[ $GIT_LAST_EXIT -eq 0 ]]; then
    printf '%s' "$(trim_line "$GIT_LAST_OUTPUT")"
    return 0
  fi

  return 1
}

has_origin() {
  run_git allow_fail remote get-url origin
  [[ $GIT_LAST_EXIT -eq 0 ]]
}

has_upstream() {
  run_git allow_fail rev-parse --abbrev-ref --symbolic-full-name '@{u}'
  [[ $GIT_LAST_EXIT -eq 0 ]]
}

get_ahead_count() {
  if ! has_upstream; then
    printf '0'
    return 0
  fi

  run_git allow_fail rev-list --count '@{u}..HEAD'
  if [[ $GIT_LAST_EXIT -ne 0 ]]; then
    printf '0'
    return 0
  fi

  local count
  count="$(trim_line "$GIT_LAST_OUTPUT")"
  if is_integer "$count"; then
    printf '%s' "$count"
  else
    printf '0'
  fi
}

invoke_sync() {
  if [[ $IS_SYNCING -eq 1 ]]; then
    write_log "WARN" "A sync is already running; skipping this trigger."
    return 0
  fi

  IS_SYNCING=1
  local branch=""
  local has_upstream_flag=0
  local ahead=0

  if ! test_git_repository; then
    IS_SYNCING=0
    return 1
  fi

  if ! branch="$(get_current_branch)"; then
    write_log "ERROR" "Branch not found. Sync stopped."
    IS_SYNCING=0
    return 1
  fi

  if [[ -z "$branch" ]]; then
    write_log "ERROR" "Branch not found. Sync stopped."
    IS_SYNCING=0
    return 1
  fi

  if ! run_git strict add -A; then
    IS_SYNCING=0
    return 1
  fi

  run_git allow_fail diff --cached --name-only
  if [[ $GIT_LAST_EXIT -eq 0 && -n "$(trim_line "$GIT_LAST_OUTPUT")" ]]; then
    local stamp
    stamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
    run_git allow_fail commit -m "notes: auto-sync $stamp"
    if [[ $GIT_LAST_EXIT -ne 0 ]]; then
      write_log "ERROR" "Commit failed. $GIT_LAST_OUTPUT"
      IS_SYNCING=0
      return 1
    fi
    write_log "INFO" "Commit created on '$branch'."
  else
    write_log "INFO" "No new staged changes."
  fi

  if ! has_origin; then
    write_log "WARN" "Remote 'origin' not configured. Skipping pull/push."
    IS_SYNCING=0
    return 0
  fi

  if has_upstream; then
    has_upstream_flag=1
    run_git allow_fail pull --rebase
    if [[ $GIT_LAST_EXIT -ne 0 ]]; then
      write_log "ERROR" "git pull --rebase failed. Resolve conflicts manually, then continue. $GIT_LAST_OUTPUT"
      IS_SYNCING=0
      return 1
    fi
    write_log "INFO" "Pull --rebase succeeded."
  else
    write_log "WARN" "Upstream missing for '$branch'. First push will set upstream."
  fi

  ahead="$(get_ahead_count)"
  if [[ ! "$ahead" =~ ^[0-9]+$ ]]; then
    ahead=0
  fi

  if [[ $ahead -gt 0 || $has_upstream_flag -eq 0 ]]; then
    if [[ $has_upstream_flag -eq 1 ]]; then
      run_git allow_fail push
    else
      run_git allow_fail push -u origin "$branch"
    fi

    if [[ $GIT_LAST_EXIT -ne 0 ]]; then
      write_log "ERROR" "Push failed. Local commits are kept and will retry on next change. $GIT_LAST_OUTPUT"
      IS_SYNCING=0
      return 1
    fi
    write_log "INFO" "Push succeeded."
  else
    write_log "INFO" "No commits to push."
  fi

  IS_SYNCING=0
  return 0
}

snapshot_watch_folders() {
  {
    local folder
    for folder in "${WATCH_FOLDERS[@]}"; do
      local path="$REPO_PATH/$folder"
      mkdir -p "$path"

      while IFS= read -r -d '' file; do
        local relative
        local meta
        relative="${file#$REPO_PATH/}"
        meta="$(stat -f '%m|%z' "$file" 2>/dev/null || printf '0|0')"
        printf '%s|%s\n' "$relative" "$meta"
      done < <(find "$path" -type f -name '*.md' -print0 2>/dev/null)
    done
  } | LC_ALL=C sort | shasum | awk '{print $1}'
}

cleanup() {
  if [[ $STOPPED -eq 1 ]]; then
    return 0
  fi
  STOPPED=1
  write_log "INFO" "Shutting down auto sync watcher."
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
  --watch-folders)
    IFS=',' read -r -a WATCH_FOLDERS <<<"$2"
    shift 2
    ;;
  --log-file)
    LOG_FILE="$2"
    shift 2
    ;;
  --run-once)
    RUN_ONCE=1
    shift
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

if ! is_integer "$DEBOUNCE_SECONDS"; then
  printf "debounce-seconds must be an integer: %s\n" "$DEBOUNCE_SECONDS" >&2
  exit 1
fi

if ! is_integer "$POLL_SECONDS"; then
  printf "poll-seconds must be an integer: %s\n" "$POLL_SECONDS" >&2
  exit 1
fi

if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="$REPO_PATH/logs/auto-sync.log"
fi

if [[ $RUN_ONCE -eq 1 ]]; then
  invoke_sync
  exit 0
fi

trap cleanup INT TERM EXIT

write_log "INFO" "Auto sync started. Repo='$REPO_PATH', debounce=${DEBOUNCE_SECONDS}s."
write_log "INFO" "Watching folders: ${WATCH_FOLDERS[*]} (poll=${POLL_SECONDS}s)."

previous_snapshot="$(snapshot_watch_folders)"
last_change_epoch=0

while true; do
  current_snapshot="$(snapshot_watch_folders)"
  if [[ "$current_snapshot" != "$previous_snapshot" ]]; then
    write_log "INFO" "Detected file change in watched folders."
    previous_snapshot="$current_snapshot"
    last_change_epoch="$(date +%s)"
  fi

  if [[ "$last_change_epoch" -gt 0 ]]; then
    now_epoch="$(date +%s)"
    if ((now_epoch - last_change_epoch >= DEBOUNCE_SECONDS)); then
      invoke_sync || true
      previous_snapshot="$(snapshot_watch_folders)"
      last_change_epoch=0
    fi
  fi

  sleep "$POLL_SECONDS"
done
