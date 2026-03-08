#!/usr/bin/env python3
from __future__ import annotations

import html
import json
import os
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import List
from urllib.parse import quote

import markdown


ROOT = Path(__file__).resolve().parent.parent
SOURCE_ROOTS = ("inbox", "courses", "topics")
NOTES_OUT_DIR = ROOT / "notes"
TOC_MODE_KEY = "tocMode"
EXCLUDED_NOTE_PATTERNS = (
    re.compile(r"^inbox/\d{4}-\d{2}-\d{2}-\d{6}-auto-sync-test(?:-\d+)?\.md$", re.IGNORECASE),
    re.compile(r"^courses/.+\.backup-\d{8}-\d{6}\.md$", re.IGNORECASE),
)


@dataclass
class Note:
    rel_path: str
    title: str
    updated: str
    url: str
    back_to_index_url: str
    source_url: str
    html_content: str
    plain_text: str


NOTE_TEMPLATE = r"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>__TITLE__</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/github-markdown-css@5.8.1/github-markdown.min.css">
  <style>
    :root {
      --bg: #f6f8fa;
      --card: #ffffff;
      --text: #24292f;
      --muted: #57606a;
      --line: #d0d7de;
      --link: #0969da;
      --active-bg: #ddf4ff;
      --active-text: #0550ae;
      --shadow: 0 8px 24px rgba(31, 35, 40, 0.15);
    }
    * { box-sizing: border-box; }
    html {
      height: 100%;
      scroll-behavior: smooth;
    }
    body {
      height: 100%;
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif;
      line-height: 1.7;
      overflow: hidden;
    }
    .wrap {
      max-width: 1520px;
      height: 100vh;
      margin: 0 auto;
      padding: 16px 20px;
      display: grid;
      grid-template-rows: auto minmax(0, 1fr);
      gap: 16px;
    }
    .card {
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 10px;
      padding: 16px;
    }
    .head {
      padding: 14px 18px;
      display: grid;
      grid-template-columns: minmax(0, 1fr) auto;
      gap: 10px 20px;
      align-items: start;
    }
    .head h1 {
      margin: 0;
      font-size: 28px;
      line-height: 1.2;
    }
    .head-main {
      min-width: 0;
    }
    .head-side {
      display: flex;
      flex-direction: column;
      align-items: flex-end;
      gap: 10px;
    }
    .meta-row {
      display: flex;
      flex-wrap: wrap;
      gap: 8px 18px;
      margin-top: 8px;
    }
    .meta {
      color: var(--muted);
      font-size: 14px;
      margin: 0;
      word-break: break-all;
    }
    .actions {
      margin: 0;
      font-size: 14px;
      display: flex;
      flex-wrap: wrap;
      gap: 8px 12px;
      justify-content: flex-end;
    }
    .actions a { color: var(--link); text-decoration: none; margin-right: 12px; }
    .actions a:last-child { margin-right: 0; }
    .actions a:hover { text-decoration: underline; }

    .toc-mode {
      display: inline-flex;
      gap: 8px;
      align-items: center;
      flex-wrap: wrap;
    }
    .toc-mode button {
      border: 1px solid var(--line);
      background: #fff;
      color: #1f2328;
      border-radius: 999px;
      padding: 4px 12px;
      font-size: 12px;
      cursor: pointer;
    }
    .toc-mode button.active {
      border-color: #54aeff;
      background: var(--active-bg);
      color: var(--active-text);
      font-weight: 600;
    }

    .layout {
      min-height: 0;
      display: grid;
      grid-template-columns: minmax(0, 1fr) 290px;
      gap: 16px;
      align-items: stretch;
    }

    #content {
      min-width: 0;
      min-height: 0;
      height: 100%;
      padding: 28px 32px;
      overflow-y: auto;
      overflow-x: auto;
    }
    #content.markdown-body {
      background: #fff;
      color: #1f2328;
    }
    #content h1, #content h2, #content h3 { scroll-margin-top: 18px; }

    .desktop-toc {
      min-height: 0;
    }
    .toc-panel {
      height: 100%;
      max-height: none;
      overflow-y: auto;
      overflow-x: hidden;
    }

    .toc-title { margin: 0 0 8px; font-size: 18px; }
    .toc-nav ul { list-style: none; margin: 0; padding: 0; }
    .toc-nav ul ul {
      margin-left: 12px;
      padding-left: 10px;
      border-left: 1px solid #d8dee4;
    }
    .toc-nav li { margin: 4px 0; }
    .toc-nav a {
      color: #1f2328;
      text-decoration: none;
      display: block;
      padding: 4px 6px;
      border-radius: 6px;
      word-break: break-word;
      font-size: 14px;
      line-height: 1.45;
    }
    .toc-nav a:hover { background: #f6f8fa; }
    .toc-nav a.active {
      background: var(--active-bg);
      color: var(--active-text);
      font-weight: 600;
    }
    .toc-empty {
      color: var(--muted);
      margin: 0;
      font-size: 14px;
    }

    .toc-fab {
      position: fixed;
      right: 16px;
      bottom: 20px;
      z-index: 1000;
      display: none;
      border: 0;
      border-radius: 999px;
      padding: 12px 16px;
      font-size: 14px;
      font-weight: 600;
      color: #fff;
      background: #0969da;
      cursor: pointer;
      box-shadow: var(--shadow);
    }

    .toc-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.35);
      z-index: 1001;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.2s ease;
    }
    .toc-overlay.active {
      opacity: 1;
      pointer-events: auto;
    }

    .toc-drawer {
      position: fixed;
      right: 0;
      top: 0;
      width: min(88vw, 380px);
      height: 100vh;
      background: #fff;
      border-left: 1px solid var(--line);
      box-shadow: var(--shadow);
      transform: translateX(100%);
      transition: transform 0.2s ease;
      z-index: 1002;
      display: flex;
      flex-direction: column;
    }
    .toc-drawer.open { transform: translateX(0); }

    .toc-drawer-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 16px;
      border-bottom: 1px solid var(--line);
    }
    .toc-drawer-head h2 { margin: 0; font-size: 18px; }

    .toc-drawer-close {
      border: 0;
      background: transparent;
      font-size: 24px;
      line-height: 1;
      cursor: pointer;
      color: #57606a;
      padding: 0 4px;
    }

    .toc-drawer-body {
      overflow-y: auto;
      padding: 12px;
    }

    @media (max-width: 820px), (pointer: coarse) and (max-width: 1200px) {
      body {
        height: auto;
        overflow: auto;
      }
      .wrap {
        height: auto;
        min-height: 100vh;
        margin: 24px auto;
        padding: 0 16px 24px;
        display: block;
      }
      .head {
        grid-template-columns: 1fr;
        gap: 10px;
      }
      .head-side {
        align-items: flex-start;
      }
      .actions {
        justify-content: flex-start;
      }
      .layout { grid-template-columns: 1fr; }
      .desktop-toc { display: none; }
      .toc-fab { display: inline-block; }
      #content {
        height: auto;
        min-height: unset;
        overflow-y: visible;
      }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <section class="card head">
      <div class="head-main">
        <h1 id="title">__TITLE__</h1>
        <div class="meta-row">
          <p class="meta">Path: __PATH__</p>
          <p class="meta">Updated: __UPDATED__</p>
        </div>
      </div>
      <div class="head-side">
        <p class="actions">
          <a href="__BACK_TO_INDEX__">Back to index</a>
          <a href="__SOURCE_URL__" target="_blank" rel="noopener noreferrer">Open source (.md)</a>
        </p>
        <div class="toc-mode" aria-label="Table of contents mode">
          <button type="button" id="mode-h1" data-mode="h1">H1</button>
          <button type="button" id="mode-h13" data-mode="h13">H1-H3</button>
        </div>
      </div>
    </section>

    <section class="layout">
      <article id="content" class="card markdown-body">
__CONTENT__
      </article>
      <aside class="desktop-toc">
        <div class="card toc-panel" id="desktop-toc-panel">
          <h2 class="toc-title">Contents</h2>
          <nav id="desktop-toc" class="toc-nav"></nav>
        </div>
      </aside>
    </section>
  </div>

  <button id="toc-fab" class="toc-fab" type="button" aria-controls="toc-drawer" aria-expanded="false">Contents</button>
  <div id="toc-overlay" class="toc-overlay"></div>
  <aside id="toc-drawer" class="toc-drawer" aria-hidden="true">
    <div class="toc-drawer-head">
      <h2>Contents</h2>
      <button id="toc-drawer-close" class="toc-drawer-close" type="button" aria-label="Close contents">&times;</button>
    </div>
    <div class="toc-drawer-body">
      <nav id="mobile-toc" class="toc-nav"></nav>
    </div>
  </aside>

  <script>
    (function () {
      const MODE_KEY = "__TOC_MODE_KEY__";
      const contentEl = document.getElementById("content");
      const desktopTocEl = document.getElementById("desktop-toc");
      const mobileTocEl = document.getElementById("mobile-toc");
      const modeH1El = document.getElementById("mode-h1");
      const modeH13El = document.getElementById("mode-h13");
      const tocFabEl = document.getElementById("toc-fab");
      const drawerEl = document.getElementById("toc-drawer");
      const overlayEl = document.getElementById("toc-overlay");
      const drawerCloseEl = document.getElementById("toc-drawer-close");

      let activeId = "";
      let tocLinksById = {};
      let headingNodes = [];
      let mode = localStorage.getItem(MODE_KEY) === "h1" ? "h1" : "h13";
      let ticking = false;

      function isMobileLayout() {
        return window.innerWidth <= 820 || (window.matchMedia("(pointer: coarse)").matches && window.innerWidth <= 1200);
      }

      function openDrawer() {
        drawerEl.classList.add("open");
        drawerEl.setAttribute("aria-hidden", "false");
        overlayEl.classList.add("active");
        tocFabEl.setAttribute("aria-expanded", "true");
      }

      function closeDrawer() {
        drawerEl.classList.remove("open");
        drawerEl.setAttribute("aria-hidden", "true");
        overlayEl.classList.remove("active");
        tocFabEl.setAttribute("aria-expanded", "false");
      }

      function slugify(text) {
        const cleaned = text
          .trim()
          .toLowerCase()
          .replace(/\s+/g, "-")
          .replace(/[^\w\u4e00-\u9fa5-]/g, "");
        return cleaned || "section";
      }

      function getAllHeadings() {
        return Array.from(contentEl.querySelectorAll("h1,h2,h3"));
      }

      function normalizeHeadingText(text) {
        return (text || "").replace(/\s+/g, " ").trim();
      }

      function isDocumentTitleHeading(node, allHeadings) {
        if (node.tagName !== "H1" || allHeadings.length <= 1) {
          return false;
        }
        const pageTitle = normalizeHeadingText(document.getElementById("title").textContent);
        return normalizeHeadingText(node.textContent) === pageTitle;
      }

      function looksLikeTopLevelEntry(text) {
        const normalized = normalizeHeadingText(text);
        if (/^语法笔记[:：]?\s*\d+\b/.test(normalized)) {
          return true;
        }
        if (!/^\d+\b/.test(normalized)) {
          return false;
        }
        return /[～〜~]|[ぁ-ゖァ-ヺ]{2,}/.test(normalized);
      }

      function getLeadingNumber(text) {
        const match = normalizeHeadingText(text).match(/^(\d+)\b/);
        return match ? Number(match[1]) : null;
      }

      function ensureHeadingIds() {
        const all = getAllHeadings();
        const used = {};
        all.forEach(function (node) {
          const base = node.id && node.id.trim() ? node.id.trim() : slugify(node.textContent || "");
          let id = base;
          let n = 2;
          while (used[id]) {
            id = base + "-" + n;
            n += 1;
          }
          used[id] = true;
          node.id = id;
        });
      }

      function getTopLevelHeadings() {
        const all = getAllHeadings();
        const filtered = all.filter(function (node) {
          return !isDocumentTitleHeading(node, all);
        });
        const topLevel = [];
        let lastNumber = null;

        filtered.forEach(function (node) {
          const text = node.textContent || "";
          if (!looksLikeTopLevelEntry(text)) {
            return;
          }

          const normalized = normalizeHeadingText(text);
          const number = getLeadingNumber(normalized);
          const isExplicit = /^语法笔记[:：]?\s*\d+\b/.test(normalized);

          if (isExplicit || topLevel.length === 0 || number === null || lastNumber === null || number > lastNumber) {
            topLevel.push(node);
            if (number !== null) {
              lastNumber = number;
            }
          }
        });

        if (topLevel.length >= 3) {
          return topLevel;
        }

        const h1Only = filtered.filter(function (node) {
          return node.tagName === "H1";
        });
        return h1Only.length ? h1Only : filtered;
      }

      function getHeadingsByMode() {
        const allHeadings = getAllHeadings();
        const all = allHeadings.filter(function (node) {
          return !isDocumentTitleHeading(node, allHeadings);
        });
        if (mode === "h1") {
          return getTopLevelHeadings();
        }
        return all;
      }

      function updateModeButtons() {
        modeH1El.classList.toggle("active", mode === "h1");
        modeH13El.classList.toggle("active", mode === "h13");
      }

      function createTree(items, mountEl) {
        mountEl.innerHTML = "";
        const rootUl = document.createElement("ul");
        mountEl.appendChild(rootUl);
        const stack = [{ level: 0, ul: rootUl }];
        const map = {};

        items.forEach(function (item) {
          while (stack.length > 1 && item.level <= stack[stack.length - 1].level) {
            stack.pop();
          }
          const li = document.createElement("li");
          const a = document.createElement("a");
          const childUl = document.createElement("ul");

          a.href = "#" + item.id;
          a.dataset.targetId = item.id;
          a.textContent = item.text;

          li.appendChild(a);
          li.appendChild(childUl);
          stack[stack.length - 1].ul.appendChild(li);
          stack.push({ level: item.level, ul: childUl });

          if (!map[item.id]) {
            map[item.id] = [];
          }
          map[item.id].push(a);
        });

        mountEl.querySelectorAll("ul").forEach(function (ul) {
          if (!ul.children.length) {
            ul.remove();
          }
        });

        return map;
      }

      function ensureDesktopVisible(id) {
        const links = tocLinksById[id] || [];
        const desktop = links.find(function (a) { return a.closest("#desktop-toc"); });
        if (!desktop) {
          return;
        }
        desktop.scrollIntoView({ block: "nearest" });
      }

      function setActive(id) {
        if (!id) {
          return;
        }
        if (activeId !== id) {
          if (activeId && tocLinksById[activeId]) {
            tocLinksById[activeId].forEach(function (a) { a.classList.remove("active"); });
          }
          activeId = id;
          if (tocLinksById[activeId]) {
            tocLinksById[activeId].forEach(function (a) { a.classList.add("active"); });
          }
        }
        ensureDesktopVisible(id);
      }

      function updateActiveFromViewport() {
        if (!headingNodes.length) {
          return;
        }
        let triggerY = window.innerHeight * 0.28;
        if (!isMobileLayout()) {
          const contentRect = contentEl.getBoundingClientRect();
          triggerY = contentRect.top + Math.min(contentEl.clientHeight * 0.28, 180);
        }
        let candidate = headingNodes[0].id;
        for (let i = 0; i < headingNodes.length; i += 1) {
          const top = headingNodes[i].getBoundingClientRect().top;
          if (top <= triggerY) {
            candidate = headingNodes[i].id;
          } else {
            break;
          }
        }
        setActive(candidate);
      }

      function renderToc() {
        updateModeButtons();
        activeId = "";
        tocLinksById = {};

        const selected = getHeadingsByMode();
        if (!selected.length) {
          desktopTocEl.innerHTML = '<p class="toc-empty">No headings</p>';
          mobileTocEl.innerHTML = '<p class="toc-empty">No headings</p>';
          headingNodes = [];
          return;
        }

        const items = selected.map(function (h) {
          return {
            id: h.id,
            text: (h.textContent || "").trim(),
            level: mode === "h1" ? 1 : Number(h.tagName.slice(1))
          };
        });

        const desktopMap = createTree(items, desktopTocEl);
        const mobileMap = createTree(items, mobileTocEl);
        Object.keys(desktopMap).forEach(function (id) {
          tocLinksById[id] = (desktopMap[id] || []).concat(mobileMap[id] || []);
        });
        headingNodes = selected;

        document.querySelectorAll("#desktop-toc a, #mobile-toc a").forEach(function (a) {
          a.addEventListener("click", function (event) {
            event.preventDefault();
            const id = a.dataset.targetId;
            const target = document.getElementById(id);
            if (!target) {
              return;
            }
            target.scrollIntoView({ behavior: "smooth", block: "start" });
            if (window.history && window.history.replaceState) {
              window.history.replaceState(null, "", "#" + id);
            }
            setActive(id);
            if (isMobileLayout()) {
              closeDrawer();
            }
            setTimeout(function () {
              updateActiveFromViewport();
              setActive(id);
            }, 160);
          });
        });

        setActive(headingNodes[0].id);
        updateActiveFromViewport();
      }

      modeH1El.addEventListener("click", function () {
        mode = "h1";
        localStorage.setItem(MODE_KEY, mode);
        renderToc();
      });

      modeH13El.addEventListener("click", function () {
        mode = "h13";
        localStorage.setItem(MODE_KEY, mode);
        renderToc();
      });

      tocFabEl.addEventListener("click", function () {
        if (drawerEl.classList.contains("open")) {
          closeDrawer();
        } else {
          openDrawer();
        }
      });
      drawerCloseEl.addEventListener("click", closeDrawer);
      overlayEl.addEventListener("click", closeDrawer);
      document.addEventListener("keydown", function (evt) {
        if (evt.key === "Escape") {
          closeDrawer();
        }
      });

      window.addEventListener("resize", function () {
        if (!isMobileLayout()) {
          closeDrawer();
          tocFabEl.style.display = "none";
        } else {
          tocFabEl.style.display = "inline-block";
        }
        updateActiveFromViewport();
      });

      window.addEventListener("scroll", function () {
        if (ticking) {
          return;
        }
        ticking = true;
        requestAnimationFrame(function () {
          updateActiveFromViewport();
          ticking = false;
        });
      }, { passive: true });

      contentEl.addEventListener("scroll", function () {
        if (isMobileLayout() || ticking) {
          return;
        }
        ticking = true;
        requestAnimationFrame(function () {
          updateActiveFromViewport();
          ticking = false;
        });
      }, { passive: true });

      ensureHeadingIds();
      renderToc();
      if (isMobileLayout()) {
        tocFabEl.style.display = "inline-block";
      }
    })();
  </script>
</body>
</html>
"""


def git_output(args: List[str]) -> str:
    proc = subprocess.run(
        args,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout.strip()


def detect_github_repo() -> tuple[str, str]:
    gh_repo = (os.environ.get("GITHUB_REPOSITORY") or "").strip()
    if gh_repo and "/" in gh_repo:
        owner, repo = gh_repo.split("/", 1)
        return owner, repo

    remote = git_output(["git", "-C", str(ROOT), "config", "--get", "remote.origin.url"])
    if remote:
        m = re.search(r"github\\.com[:/](?P<owner>[^/]+)/(?P<repo>[^/.]+)(?:\\.git)?$", remote.strip())
        if m:
            return m.group("owner"), m.group("repo")

    return "linafoce", "language"


def run_git_last_updated(rel_path: str) -> str:
    out = git_output(["git", "-C", str(ROOT), "log", "-1", "--format=%cI", "--", rel_path])
    if out:
        return out
    dt = datetime.fromtimestamp((ROOT / rel_path).stat().st_mtime, tz=timezone.utc)
    return dt.isoformat()


def md_to_html(md_text: str) -> str:
    return markdown.markdown(
        md_text,
        extensions=["extra", "sane_lists", "fenced_code", "tables"],
    )


def extract_title(md_text: str, fallback: str) -> str:
    for line in md_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("# "):
            return stripped[2:].strip() or fallback
    return fallback


def md_to_plain(md_text: str) -> str:
    text = re.sub(r"```[\s\S]*?```", " ", md_text)
    text = re.sub(r"`[^`]+`", " ", text)
    text = re.sub(r"!\[[^\]]*\]\([^)]+\)", " ", text)
    text = re.sub(r"\[[^\]]+\]\([^)]+\)", " ", text)
    text = re.sub(r"^#{1,6}\s*", " ", text, flags=re.MULTILINE)
    text = re.sub(r"[*_~>\-]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def rel_to_url(rel_path: str) -> str:
    parts = rel_path.split("/")
    if not parts[-1].lower().endswith(".md"):
        raise ValueError(f"Not a markdown file: {rel_path}")
    parts[-1] = parts[-1][:-3] + ".html"
    return "notes/" + "/".join(quote(p) for p in parts)


def build_back_to_index_url(rel_path: str) -> str:
    depth = len(rel_path.split("/"))
    return "../" * depth + "index.html"


def render_note_page(note: Note) -> str:
    html_doc = NOTE_TEMPLATE
    html_doc = html_doc.replace("__TITLE__", html.escape(note.title))
    html_doc = html_doc.replace("__PATH__", html.escape(note.rel_path))
    html_doc = html_doc.replace("__UPDATED__", html.escape(note.updated))
    html_doc = html_doc.replace("__BACK_TO_INDEX__", note.back_to_index_url)
    html_doc = html_doc.replace("__SOURCE_URL__", note.source_url)
    html_doc = html_doc.replace("__TOC_MODE_KEY__", TOC_MODE_KEY)
    html_doc = html_doc.replace("__CONTENT__", note.html_content)
    return html_doc


def should_include_note(rel_path: str) -> bool:
    return not any(pattern.search(rel_path) for pattern in EXCLUDED_NOTE_PATTERNS)


def load_notes(owner: str, repo: str) -> List[Note]:
    notes: List[Note] = []
    for root_name in SOURCE_ROOTS:
        root_dir = ROOT / root_name
        if not root_dir.exists():
            continue
        for path in sorted(root_dir.rglob("*.md")):
            rel = path.relative_to(ROOT).as_posix()
            if not should_include_note(rel):
                continue
            md_text = path.read_text(encoding="utf-8-sig")
            title = extract_title(md_text, path.stem)
            updated = run_git_last_updated(rel)
            url = rel_to_url(rel)
            html_content = md_to_html(md_text)
            plain_text = md_to_plain(md_text)
            back_to_index_url = build_back_to_index_url(rel)
            source_url = f"https://github.com/{owner}/{repo}/blob/main/{quote(rel)}"
            notes.append(
                Note(
                    rel_path=rel,
                    title=title,
                    updated=updated,
                    url=url,
                    back_to_index_url=back_to_index_url,
                    source_url=source_url,
                    html_content=html_content,
                    plain_text=plain_text,
                )
            )
    return notes


def sort_recent(notes: List[Note]) -> List[Note]:
    def key_func(note: Note):
        value = note.updated.replace("Z", "+00:00")
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            return datetime.min.replace(tzinfo=timezone.utc)

    return sorted(notes, key=key_func, reverse=True)


def write_outputs(notes: List[Note]) -> None:
    NOTES_OUT_DIR.mkdir(parents=True, exist_ok=True)

    for note in notes:
        out_file = NOTES_OUT_DIR / Path(note.rel_path).with_suffix(".html")
        out_file.parent.mkdir(parents=True, exist_ok=True)
        out_file.write_text(render_note_page(note), encoding="utf-8")

    notes_payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "notes": [
            {
                "path": n.rel_path,
                "title": n.title,
                "url": n.url,
                "updated": n.updated,
            }
            for n in notes
        ],
    }

    search_payload = [
        {
            "id": idx + 1,
            "path": n.rel_path,
            "title": n.title,
            "url": n.url,
            "updated": n.updated,
            "body": n.plain_text,
        }
        for idx, n in enumerate(notes)
    ]

    recent_sorted = sort_recent(notes)
    recent_payload = [
        {
            "path": n.rel_path,
            "title": n.title,
            "url": n.url,
            "updated": n.updated,
        }
        for n in recent_sorted[:20]
    ]

    (ROOT / "notes.json").write_text(
        json.dumps(notes_payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (ROOT / "search-index.json").write_text(
        json.dumps(search_payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (ROOT / "recent.json").write_text(
        json.dumps(recent_payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    owner, repo = detect_github_repo()
    notes = load_notes(owner, repo)
    write_outputs(notes)
    print(f"Rendered {len(notes)} note pages into {NOTES_OUT_DIR}")


if __name__ == "__main__":
    main()
