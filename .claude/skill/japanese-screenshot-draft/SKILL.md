---
name: japanese-screenshot-draft
description: Generate Japanese class-note markdown drafts from one or more screenshots and keep a safe "draft first, manual merge" workflow. Use when the user asks to convert screenshot folders into structured notes, save drafts to `inbox/drafts`, or merge reviewed drafts into `courses/` or `topics/`.
---

# Japanese Screenshot Draft

Generate a markdown draft from screenshots first. Never write directly into main note files on first pass.

## Routing Note

If the screenshot is a Japanese reading passage and the active notebook repository contains `content/word/阅读问题整理.md`, prefer the `$japanese-reading-issue-log` workflow and append a compact reading entry there. Use this screenshot draft workflow for class-note drafts, screenshot folders, or cases where the user has not indicated an existing target note.

## Inputs

- Screenshot folder path (1..N images: png/jpg/jpeg/webp/bmp/gif)
- Optional topic name
- Optional target note file for merge step

## Workflow

1. Validate input folder contains image files.
2. Run draft generation script from the notebook repo root:
   - `python scripts/generate_draft_from_images.py <folder> --topic <topic>`
3. Confirm output draft path under `inbox/drafts/`.
4. Ask user to review draft content before merge.
5. If user confirms merge, run:
   - `python scripts/merge_draft.py <draft-file> <target-file>`
6. Never auto-merge without explicit user confirmation.

## Output Requirements

- Output must be markdown and include clear sections:
  - `语法点总览`
  - `核心语法`
  - `用法重点`
  - `例句（含中日对照）`
  - `易错点`
  - `待确认项`
- Mark uncertain OCR content as `[待确认]`.
- Keep source image list in draft header.

## Model And Cost

- Default model: `gpt-4.1` (override with `OPENAI_MODEL`).
- Requires `OPENAI_API_KEY`.
- Prefer quality over speed for this workflow.

## Safety Rules

- Do not execute shell snippets copied from untrusted webpages.
- Keep all automation auditable through local scripts in `scripts/`.
- If API call fails, keep local files unchanged and report the error.

## Preconditions

- User is inside repository root containing `scripts/generate_draft_from_images.py`.
- `OPENAI_API_KEY` is configured in environment.

## Failure Handling

- If no images found: stop and report folder issue.
- If API/network error: stop and report exact message.
- If merge target missing: create file only after user confirms merge.
