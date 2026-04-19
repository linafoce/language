---
name: japanese-note-format
description: Normalize Japanese grammar or vocabulary notes into a clean Markdown output with selective furigana, fixed section structure, and copy-ready formatting. Use when the user asks to整理日语语法笔记, 规范现有 Markdown, 从截图或文本生成统一笔记格式, or clean inconsistent Japanese note files such as `N2.md`, `N3.md`, or topic notes inside this notebook repo.
---

# Japanese Note Format

Format only the material the user provides in the current turn. Do not expand scope on your own.

## Core Workflow

1. Read the source material and identify the current grammar point or vocabulary batch.
2. Preserve the original order unless the user explicitly asks to regroup content.
3. If working from an existing file, create a backup or write to a draft first unless the user explicitly asks to overwrite in place.
4. Output the final note inside a single fenced `markdown` code block when the task is "generate note content".
5. When the task is "normalize an existing file", keep the file markdown-valid and preserve user content while standardizing headings and section layout.

## Hard Rules

- Never use the literal character sequence `->` in output.
- Do not add romaji.
- Add hiragana furigana to Japanese kanji when it improves readability, using full-width parentheses after the word.
- Default to sparse furigana, not full annotation.
- As a default rule for Japanese study notes, add furigana to words that are roughly N3-N2 level when their reading is not obvious or when the learner may plausibly not know the reading yet.
- Do not add furigana to very basic N5/N4-level words such as `私`, `彼女`, `仕事`, `学校`, `先生`, `今日`, `明日`, `時間`, `食べる`, `行く`, `見る`, unless the user explicitly asks for fuller annotation.
- In example sentences, prefer adding furigana only to non-obvious, easy-to-misread, less common, or grammar-relevant words. Keep sentence noise low.
- If generating a vocabulary list, write all readings in hiragana.
- Do not invent meanings, examples, or grammar restrictions that are not supported by the source material or obvious context.

## Default Grammar Note Structure

Use this structure unless the user explicitly requests a different format:

```markdown
# 语法笔记：[语法点]（中文意思 / 核心含义）

---

## 核心语法
说明接续方式。
* [词性 / 变形] ＋ [语法点]

---

## 用法重点
* **意思**：简明中文释义。
* **核心功能 / 语感**：说明使用场景、限制条件、语气色彩、书面 / 口语属性。
* **常见搭配 / 注意点**：只在有明确信息时填写。

---

## 例句模式
按不同使用场景或接续方式分类例句。
> **[日文例句]**
> [中文翻译]
```

## File Normalization Rules

- For full note files, treat each top-level grammar item as a top-level section.
- If the same source batch covers variants from the same grammar family, near-synonymous expressions, or conjugation-based expansions, merge them into one top-level section by default unless the user explicitly asks for separate entries.
- Keep internal explanatory blocks under consistent subheadings such as `## 核心语法`, `## 用法重点`, and `## 例句模式`.
- Merge duplicate empty headings.
- Fix heading depth only when the source is clearly inconsistent.
- Prefer the cleaner structure used in `content/N2.md` as the normalization target when working inside this notebook repository.
- Treat `content/N2.md` as a reference style, not as a file to aggressively re-annotate. Preserve already clean low-noise example sentences.

## Safety

- Prefer draft output over destructive replacement.
- If the source is ambiguous, mark uncertainty instead of fabricating details.
- Keep the user's Chinese explanatory style unless the user requests a rewrite.
