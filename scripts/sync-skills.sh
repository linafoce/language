#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="$repo_root/.claude/skill"
dest_root="$HOME/.codex/skills"
validator="$dest_root/.system/skill-creator/scripts/quick_validate.py"

if [[ ! -d "$source_root" ]]; then
  echo "Skill source directory not found: $source_root" >&2
  exit 1
fi

mkdir -p "$dest_root"

shopt -s nullglob
skills=("$source_root"/*)
if [[ ${#skills[@]} -eq 0 ]]; then
  echo "No skills found under $source_root"
  exit 0
fi

for skill_dir in "${skills[@]}"; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"
  skill_md="$skill_dir/SKILL.md"

  if [[ ! -f "$skill_md" ]]; then
    echo "Skip $skill_name: missing SKILL.md" >&2
    continue
  fi

  if [[ -f "$validator" ]]; then
    if ! PYTHONUTF8=1 python "$validator" "$skill_dir" >/dev/null; then
      echo "Skip $skill_name: validation failed" >&2
      continue
    fi
  fi

  dest_dir="$dest_root/$skill_name"
  rm -rf "$dest_dir"
  cp -R "$skill_dir" "$dest_dir"
  echo "Synced $skill_name -> $dest_dir"
done
