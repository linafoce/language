#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Append a reviewed draft markdown into a target note file."
    )
    parser.add_argument("draft_file", help="Draft markdown file")
    parser.add_argument("target_file", help="Target markdown file")
    parser.add_argument(
        "--delete-draft",
        action="store_true",
        help="Delete draft file after successful merge",
    )
    return parser.parse_args()


def merge_draft(draft_file: Path, target_file: Path) -> str:
    if not draft_file.exists() or not draft_file.is_file():
        raise FileNotFoundError(f"Draft not found: {draft_file}")

    draft_text = draft_file.read_text(encoding="utf-8").strip()
    if not draft_text:
        raise ValueError(f"Draft is empty: {draft_file}")

    target_file.parent.mkdir(parents=True, exist_ok=True)
    existing = ""
    if target_file.exists():
        existing = target_file.read_text(encoding="utf-8")

    marker = f"<!-- merged-from: {draft_file.as_posix()} -->"
    if marker in existing:
        return "already_merged"

    merged_block = (
        "\n\n---\n\n"
        + marker
        + "\n"
        + f"<!-- merged-at: {datetime.now().isoformat(timespec='seconds')} -->"
        + "\n\n"
        + draft_text
        + "\n"
    )

    if existing.strip():
        target_file.write_text(existing.rstrip() + merged_block, encoding="utf-8")
    else:
        target_file.write_text(draft_text + "\n", encoding="utf-8")
    return "merged"


def main() -> int:
    args = parse_args()
    draft_file = Path(args.draft_file).expanduser().resolve()
    target_file = Path(args.target_file).expanduser().resolve()

    result = merge_draft(draft_file, target_file)
    if result == "already_merged":
        print(f"Skipped: draft already merged into {target_file.as_posix()}")
        return 0

    if args.delete_draft and draft_file.exists():
        draft_file.unlink()
        print(f"Merged and deleted draft: {draft_file.as_posix()}")
    else:
        print(f"Merged draft into: {target_file.as_posix()}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pylint: disable=broad-except
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
