---
name: note-format
description: Normalize Japanese grammar or vocabulary notes into a clean Markdown output with selective furigana, fixed section structure, and copy-ready formatting. Use when the user asks to整理日语语法笔记, 规范现有 Markdown, 从截图或文本生成统一笔记格式, or clean inconsistent note files such as `N2.md` or `N3.md`.
---

# Note Format

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
- Do not add furigana to very basic N5/N4-level words such as `私`, `彼女`, `仕事`, `学校`, `先生`, unless the user explicitly asks for full annotation.
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
- Keep internal explanatory blocks under consistent subheadings such as `## 核心语法`, `## 用法重点`, and `## 例句模式`.
- Merge duplicate empty headings.
- Fix heading depth only when the source is clearly inconsistent.
- Prefer the cleaner structure used in `courses/N2.md` as the normalization target when working inside this notebook repository.

## Safety

- Prefer draft output over destructive replacement.
- If the source is ambiguous, mark uncertainty instead of fabricating details.
- Keep the user's Chinese explanatory style unless the user requests a rewrite.
