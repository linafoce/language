#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: bash ./scripts/generate-draft-from-images.sh <folder> [topic]" >&2
  exit 2
fi

FOLDER="$1"
TOPIC="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "$TOPIC" ]]; then
  python "$SCRIPT_DIR/generate_draft_from_images.py" "$FOLDER" --topic "$TOPIC"
else
  python "$SCRIPT_DIR/generate_draft_from_images.py" "$FOLDER"
fi
