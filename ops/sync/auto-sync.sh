#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_PATH="$(cd "$SCRIPT_DIR/../.." && pwd)"

REPO_PATH="$DEFAULT_REPO_PATH"
DEBOUNCE_SECONDS=15
SYNC_INTERVAL_SECONDS=120
POLL_SECONDS=2
WATCH_FOLDERS=("content" "drafts")
LOG_FILE=""
RUN_ONCE=0
WATCHER_LOCK_DIR=""
SYNC_LOCK_DIR=""

IS_SYNCING=0
STOPPED=0
GIT_LAST_EXIT=0
GIT_LAST_OUTPUT=""
HELD_WATCHER_LOCK=0
HELD_SYNC_LOCK=0

usage() {
  cat <<'EOF'
Usage: auto-sync.sh [options]
  --repo-path PATH          Git repo path (default: script parent directory)
  --debounce-seconds N      Debounce delay before sync (default: 15)
  --sync-interval-seconds N Periodic pull interval when idle (default: 120, 0=disable)
  --poll-seconds N          Poll interval for file change detection (default: 2)
  --watch-folders LIST      Comma separated folders (default: content,drafts)
  --log-file PATH           Log path (default: <repo>/logs/auto-sync.log)
  --run-once                Run one sync and exit
  --help                    Show help
EOF
}

trim_line() {
  printf '%s' "$1" | tr -d '\r' | head -n 1
}

lock_pid_file() {
  printf '%s/pid' "$1"
}

release_lock_dir() {
  local lock_dir="$1"
  local pid_file
  pid_file="$(lock_pid_file "$lock_dir")"

  if [[ -f "$pid_file" ]]; then
    rm -f "$pid_file"
  fi
  rmdir "$lock_dir" 2>/dev/null || true
}

acquire_lock_dir() {
  local lock_dir="$1"
  local pid_file
  local existing_pid=""

  pid_file="$(lock_pid_file "$lock_dir")"

  if mkdir "$lock_dir" 2>/dev/null; then
    printf '%s\n' "$$" >"$pid_file"
    return 0
  fi

  if [[ -f "$pid_file" ]]; then
    existing_pid="$(cat "$pid_file" 2>/dev/null || true)"
  fi

  if [[ "$existing_pid" =~ ^[0-9]+$ ]] && kill -0 "$existing_pid" 2>/dev/null; then
    return 1
  fi

  release_lock_dir "$lock_dir"

  if mkdir "$lock_dir" 2>/dev/null; then
    printf '%s\n' "$$" >"$pid_file"
    return 0
  fi

  return 1
}

acquire_sync_lock() {
  if acquire_lock_dir "$SYNC_LOCK_DIR"; then
    HELD_SYNC_LOCK=1
    return 0
  fi

  write_log "WARN" "Another sync operation is already running; skipping this trigger."
  return 1
}

release_sync_lock() {
  if [[ $HELD_SYNC_LOCK -eq 1 ]]; then
    release_lock_dir "$SYNC_LOCK_DIR"
    HELD_SYNC_LOCK=0
  fi
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

get_upstream_ref() {
  run_git allow_fail rev-parse --abbrev-ref --symbolic-full-name '@{u}'
  if [[ $GIT_LAST_EXIT -eq 0 ]]; then
    printf '%s' "$(trim_line "$GIT_LAST_OUTPUT")"
    return 0
  fi

  return 1
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

is_working_tree_clean() {
  run_git allow_fail status --porcelain
  [[ $GIT_LAST_EXIT -eq 0 && -z "$GIT_LAST_OUTPUT" ]]
}

is_lock_error_output() {
  local output="$1"
  [[ "$output" == *".lock"* ]] \
    || [[ "$output" == *"Unable to create"* ]] \
    || [[ "$output" == *"另一个 git 进程"* ]] \
    || [[ "$output" == *"another git process"* ]]
}

is_git_busy() {
  local git_dir="$REPO_PATH/.git"

  [[ -e "$git_dir/index.lock" ]] \
    || [[ -e "$git_dir/FETCH_HEAD.lock" ]] \
    || [[ -e "$git_dir/shallow.lock" ]] \
    || [[ -e "$git_dir/packed-refs.lock" ]] \
    || [[ -d "$git_dir/rebase-merge" ]] \
    || [[ -d "$git_dir/rebase-apply" ]] \
    || [[ -e "$git_dir/MERGE_HEAD" ]] \
    || [[ -e "$git_dir/CHERRY_PICK_HEAD" ]] \
    || [[ -e "$git_dir/REVERT_HEAD" ]]
}

is_up_to_date_output() {
  local output="$1"
  [[ "$output" =~ [Aa]lready[[:space:]-]+up[[:space:]-]+to[[:space:]-]+date ]] \
    || [[ "$output" =~ up[[:space:]]to[[:space:]]date ]] \
    || [[ "$output" =~ [Cc]urrent[[:space:]]branch.+is[[:space:]]up[[:space:]]to[[:space:]]date ]]
}

fetch_and_rebase_upstream() {
  local upstream_ref=""
  local remote_name=""
  local remote_branch=""
  local fetch_output=""
  local rebase_output=""

  if ! upstream_ref="$(get_upstream_ref)"; then
    GIT_LAST_EXIT=1
    GIT_LAST_OUTPUT="Upstream branch not found."
    return 1
  fi

  remote_name="${upstream_ref%%/*}"
  remote_branch="${upstream_ref#*/}"

  run_git allow_fail fetch "$remote_name" "$remote_branch"
  if [[ $GIT_LAST_EXIT -ne 0 ]]; then
    return 1
  fi
  fetch_output="$GIT_LAST_OUTPUT"

  run_git allow_fail rebase "$upstream_ref"
  rebase_output="$GIT_LAST_OUTPUT"

  if [[ -n "$fetch_output" && -n "$rebase_output" ]]; then
    GIT_LAST_OUTPUT="$fetch_output"$'\n'"$rebase_output"
  elif [[ -n "$rebase_output" ]]; then
    GIT_LAST_OUTPUT="$rebase_output"
  else
    GIT_LAST_OUTPUT="$fetch_output"
  fi

  return $GIT_LAST_EXIT
}

invoke_pull_only() {
  if [[ $IS_SYNCING -eq 1 ]]; then
    return 0
  fi

  IS_SYNCING=1

  if ! acquire_sync_lock; then
    IS_SYNCING=0
    return 0
  fi

  if ! test_git_repository; then
    release_sync_lock
    IS_SYNCING=0
    return 1
  fi

  if ! get_current_branch >/dev/null 2>&1; then
    release_sync_lock
    IS_SYNCING=0
    return 1
  fi

  if ! has_origin || ! has_upstream; then
    release_sync_lock
    IS_SYNCING=0
    return 0
  fi

  if is_git_busy; then
    write_log "INFO" "Periodic sync skipped because Git is busy or another Git operation is in progress."
    release_sync_lock
    IS_SYNCING=0
    return 0
  fi

  if ! is_working_tree_clean; then
    write_log "INFO" "Periodic pull skipped because local workspace has uncommitted changes."
    release_sync_lock
    IS_SYNCING=0
    return 0
  fi

  fetch_and_rebase_upstream
  if [[ $GIT_LAST_EXIT -ne 0 ]]; then
    if is_lock_error_output "$GIT_LAST_OUTPUT"; then
      write_log "INFO" "Periodic sync skipped because Git is busy: $GIT_LAST_OUTPUT"
      release_sync_lock
      IS_SYNCING=0
      return 0
    fi
    write_log "ERROR" "Periodic fetch/rebase failed. $GIT_LAST_OUTPUT"
    release_sync_lock
    IS_SYNCING=0
    return 1
  fi

  if [[ -n "$GIT_LAST_OUTPUT" ]] && ! is_up_to_date_output "$GIT_LAST_OUTPUT"; then
    write_log "INFO" "Periodic fetch/rebase applied updates."
  fi

  release_sync_lock
  IS_SYNCING=0
  return 0
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

  if ! acquire_sync_lock; then
    IS_SYNCING=0
    return 0
  fi

  if ! test_git_repository; then
    release_sync_lock
    IS_SYNCING=0
    return 1
  fi

  if ! branch="$(get_current_branch)"; then
    write_log "ERROR" "Branch not found. Sync stopped."
    release_sync_lock
    IS_SYNCING=0
    return 1
  fi

  if [[ -z "$branch" ]]; then
    write_log "ERROR" "Branch not found. Sync stopped."
    release_sync_lock
    IS_SYNCING=0
    return 1
  fi

  if is_git_busy; then
    write_log "INFO" "Sync skipped because Git is busy or another Git operation is in progress."
    release_sync_lock
    IS_SYNCING=0
    return 0
  fi

  if ! run_git strict add -A; then
    if is_lock_error_output "$GIT_LAST_OUTPUT"; then
      write_log "INFO" "Sync skipped because Git is busy: $GIT_LAST_OUTPUT"
      release_sync_lock
      IS_SYNCING=0
      return 0
    fi
    release_sync_lock
    IS_SYNCING=0
    return 1
  fi

  run_git allow_fail diff --cached --name-only
  if [[ $GIT_LAST_EXIT -eq 0 && -n "$(trim_line "$GIT_LAST_OUTPUT")" ]]; then
    local stamp
    stamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
    run_git allow_fail commit -m "notes: auto-sync $stamp"
    if [[ $GIT_LAST_EXIT -ne 0 ]]; then
      if is_lock_error_output "$GIT_LAST_OUTPUT"; then
        write_log "INFO" "Sync skipped because Git is busy: $GIT_LAST_OUTPUT"
        release_sync_lock
        IS_SYNCING=0
        return 0
      fi
      write_log "ERROR" "Commit failed. $GIT_LAST_OUTPUT"
      release_sync_lock
      IS_SYNCING=0
      return 1
    fi
    write_log "INFO" "Commit created on '$branch'."
  else
    write_log "INFO" "No new staged changes."
  fi

  if ! has_origin; then
    write_log "WARN" "Remote 'origin' not configured. Skipping pull/push."
    release_sync_lock
    IS_SYNCING=0
    return 0
  fi

  if has_upstream; then
    has_upstream_flag=1
    fetch_and_rebase_upstream
    if [[ $GIT_LAST_EXIT -ne 0 ]]; then
      if is_lock_error_output "$GIT_LAST_OUTPUT"; then
        write_log "INFO" "Sync skipped because Git is busy: $GIT_LAST_OUTPUT"
        release_sync_lock
        IS_SYNCING=0
        return 0
      fi
      write_log "ERROR" "git fetch/rebase failed. Resolve conflicts manually, then continue. $GIT_LAST_OUTPUT"
      release_sync_lock
      IS_SYNCING=0
      return 1
    fi
    write_log "INFO" "Fetch/rebase succeeded."
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
      if is_lock_error_output "$GIT_LAST_OUTPUT"; then
        write_log "INFO" "Sync skipped because Git is busy: $GIT_LAST_OUTPUT"
        release_sync_lock
        IS_SYNCING=0
        return 0
      fi
      write_log "ERROR" "Push failed. Local commits are kept and will retry on next change. $GIT_LAST_OUTPUT"
      release_sync_lock
      IS_SYNCING=0
      return 1
    fi
    write_log "INFO" "Push succeeded."
  else
    write_log "INFO" "No commits to push."
  fi

  release_sync_lock
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
  release_sync_lock
  write_log "INFO" "Shutting down auto sync watcher."
  if [[ $HELD_WATCHER_LOCK -eq 1 ]]; then
    release_lock_dir "$WATCHER_LOCK_DIR"
    HELD_WATCHER_LOCK=0
  fi
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
  --sync-interval-seconds)
    SYNC_INTERVAL_SECONDS="$2"
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

if ! is_integer "$SYNC_INTERVAL_SECONDS"; then
  printf "sync-interval-seconds must be an integer: %s\n" "$SYNC_INTERVAL_SECONDS" >&2
  exit 1
fi

if ! is_integer "$POLL_SECONDS"; then
  printf "poll-seconds must be an integer: %s\n" "$POLL_SECONDS" >&2
  exit 1
fi

if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="$REPO_PATH/logs/auto-sync.log"
fi

WATCHER_LOCK_DIR="$REPO_PATH/logs/auto-sync.lock"
SYNC_LOCK_DIR="$REPO_PATH/logs/auto-sync.sync.lock"

if [[ $RUN_ONCE -eq 1 ]]; then
  invoke_sync
  exit 0
fi

if ! acquire_lock_dir "$WATCHER_LOCK_DIR"; then
  write_log "WARN" "Another auto sync watcher is already running for '$REPO_PATH'. Exiting."
  exit 0
fi
HELD_WATCHER_LOCK=1

trap cleanup INT TERM EXIT

write_log "INFO" "Auto sync started. Repo='$REPO_PATH', debounce=${DEBOUNCE_SECONDS}s."
write_log "INFO" "Periodic pull interval: ${SYNC_INTERVAL_SECONDS}s."
write_log "INFO" "Watching folders: ${WATCH_FOLDERS[*]} (poll=${POLL_SECONDS}s)."

previous_snapshot="$(snapshot_watch_folders)"
last_change_epoch=0
last_periodic_sync_epoch="$(date +%s)"

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
      last_periodic_sync_epoch="$now_epoch"
    fi
  fi

  if [[ "$SYNC_INTERVAL_SECONDS" -gt 0 && "$last_change_epoch" -eq 0 ]]; then
    now_epoch="$(date +%s)"
    if ((now_epoch - last_periodic_sync_epoch >= SYNC_INTERVAL_SECONDS)); then
      invoke_pull_only || true
      previous_snapshot="$(snapshot_watch_folders)"
      last_periodic_sync_epoch="$now_epoch"
    fi
  fi

  sleep "$POLL_SECONDS"
done
