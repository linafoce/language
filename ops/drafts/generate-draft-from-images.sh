#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: bash ./ops/drafts/generate-draft-from-images.sh <folder> [topic]" >&2
  exit 2
fi

FOLDER="$1"
TOPIC="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PY_SCRIPT="$REPO_ROOT/tools/drafts/generate_draft_from_images.py"

if [[ -n "$TOPIC" ]]; then
  python "$PY_SCRIPT" "$FOLDER" --topic "$TOPIC"
else
  python "$PY_SCRIPT" "$FOLDER"
fi
