#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from urllib import error, request


DEFAULT_MODEL = "gpt-4.1"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a markdown draft from screenshots into drafts."
    )
    parser.add_argument("folder", help="Folder containing screenshot images")
    parser.add_argument("--topic", help="Topic for output filename/title")
    parser.add_argument("--model", default=os.environ.get("OPENAI_MODEL", DEFAULT_MODEL))
    parser.add_argument("--out-dir", default="drafts")
    parser.add_argument("--max-images", type=int, default=8)
    return parser.parse_args()


def sanitize_topic(text: str) -> str:
    value = text.strip().lower()
    value = re.sub(r"\s+", "-", value)
    value = re.sub(r"[^\w\u4e00-\u9fff-]", "", value)
    return value or "untitled"


def load_images(folder: Path, max_images: int) -> list[Path]:
    files = [p for p in sorted(folder.iterdir()) if p.is_file() and p.suffix.lower() in IMAGE_EXTS]
    if not files:
        raise ValueError(f"No images found in: {folder}")
    return files[:max_images]


def image_to_input_item(path: Path) -> dict:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    b64 = base64.b64encode(path.read_bytes()).decode("ascii")
    data_url = f"data:{mime};base64,{b64}"
    return {"type": "input_image", "image_url": data_url}


def build_prompt(topic: str, image_names: list[str]) -> str:
    images_text = "\n".join(f"- {name}" for name in image_names)
    return (
        "You are a Japanese language note assistant.\n"
        "Convert the screenshots into a clean markdown draft in Chinese.\n"
        "Keep uncertain OCR words marked as [待确认].\n"
        "Do not fabricate grammar details that are not visible in images.\n"
        "\n"
        f"Topic: {topic}\n"
        "Source images:\n"
        f"{images_text}\n"
        "\n"
        "Output markdown with these sections:\n"
        "# <主题标题>\n"
        "## 语法点总览\n"
        "## 核心语法\n"
        "## 用法重点\n"
        "## 例句（含中日对照）\n"
        "## 易错点\n"
        "## 待确认项\n"
    )


def call_responses_api(api_key: str, model: str, prompt: str, image_paths: list[Path]) -> str:
    content = [{"type": "input_text", "text": prompt}]
    content.extend(image_to_input_item(p) for p in image_paths)

    payload = {
        "model": model,
        "input": [{"role": "user", "content": content}],
    }

    req = request.Request(
        "https://api.openai.com/v1/responses",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with request.urlopen(req, timeout=180) as resp:
            body = resp.read().decode("utf-8")
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenAI API HTTP {exc.code}: {detail}") from exc
    except error.URLError as exc:
        raise RuntimeError(f"OpenAI API connection error: {exc}") from exc

    data = json.loads(body)
    if isinstance(data.get("output_text"), str) and data["output_text"].strip():
        return data["output_text"].strip()

    chunks: list[str] = []
    for out in data.get("output", []):
        for item in out.get("content", []):
            item_type = item.get("type")
            if item_type in {"output_text", "text"}:
                text = item.get("text")
                if isinstance(text, str) and text.strip():
                    chunks.append(text.strip())
                elif isinstance(text, dict) and isinstance(text.get("value"), str):
                    chunks.append(text["value"].strip())

    merged = "\n\n".join(part for part in chunks if part)
    if not merged:
        raise RuntimeError("No markdown text returned by the model.")
    return merged


def write_draft(out_dir: Path, topic: str, model: str, images: list[Path], body: str) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    now = datetime.now()
    date = now.strftime("%Y-%m-%d")
    slug = sanitize_topic(topic)
    output = out_dir / f"{date}-{slug}.md"

    header = [
        f"# {topic}",
        "",
        f"> generated_at: {now.isoformat(timespec='seconds')}",
        f"> model: {model}",
        "> source_images:",
    ]
    header.extend(f"> - {img.name}" for img in images)
    header.extend(["", "---", ""])

    text = "\n".join(header) + body.strip() + "\n"
    output.write_text(text, encoding="utf-8")
    return output


def main() -> int:
    args = parse_args()
    folder = Path(args.folder).expanduser().resolve()
    if not folder.exists() or not folder.is_dir():
        print(f"Folder does not exist: {folder}", file=sys.stderr)
        return 2

    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        print("OPENAI_API_KEY is required.", file=sys.stderr)
        return 2

    topic = args.topic.strip() if args.topic else folder.name
    images = load_images(folder, args.max_images)
    prompt = build_prompt(topic, [p.name for p in images])
    body = call_responses_api(api_key, args.model, prompt, images)
    output = write_draft(Path(args.out_dir), topic, args.model, images, body)

    print(f"Draft written: {output.as_posix()}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pylint: disable=broad-except
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
