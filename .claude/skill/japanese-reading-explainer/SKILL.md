---
name: japanese-reading-explainer
description: Explain Japanese reading passages sentence by sentence in Chinese, with clean bold original sentences, N2/N3 grammar notes, hard-word readings in notes below each sentence, and clear sentence meanings. Use when the user asks to逐句解析日语阅读, 看不懂一段文章, 解释每句话是什么意思, 标注较难词语读音, or point out important grammar while keeping the explanation learner-friendly.
---

# Japanese Reading Explainer

Use this skill when the user wants help understanding a Japanese reading passage before any later note-taking or archiving.

This skill is for explanation, not for writing into `content/word/阅读问题整理.md`.
If the user later asks to archive reusable items into the repository note file, switch to `$japanese-reading-archive`.

## Core Goal

Help the learner understand the passage directly by:

- explaining each sentence in order
- keeping the original sentence clean and adding readings for likely blocker words in the notes below it
- pointing out important grammar, mainly N2/N3-relevant items
- giving a natural Chinese meaning for each sentence
- briefly clarifying references such as `これ`, `それ`, `この場合`, or omitted subjects when needed
- avoiding archive-style summary tables such as `重点语法` or `重点单词`

## Default Workflow

1. Read the visible passage carefully and preserve sentence order.
2. Split by sentence, not by isolated clauses, unless the sentence is too long to understand without a split.
3. For each sentence:
   - show the original sentence in Markdown bold so it is visually distinct from the explanation
   - keep the original sentence unannotated; do not insert furigana into the original sentence
   - list key N2/N3-level words, hard words, or grammar below the sentence
   - include readings in hiragana for vocabulary that may block comprehension
   - explain the sentence meaning in concise Chinese
4. After the passage, give a short summary of the core logic when useful.
5. Do not append standalone `重点语法` or `重点单词` sections. Those belong to `$japanese-reading-archive`.

## Reading Annotation Policy

Keep the original Japanese sentence clean by default. Do not add furigana directly inside the original sentence.

Instead, add readings in the sentence's notes for:

- N2/N3-level words
- abstract nouns
- non-obvious compound words
- easy-to-misread kanji words
- words central to understanding the sentence

Usually do not add readings for:

- very basic N5/N4 words
- words whose reading is obvious and unlikely to block the learner
- repeated easy words after the first appearance in the same explanation

Use hiragana readings, not romaji. Prefer a compact note like `語彙（ごい）：词义/文中义`.
If the user says the readings are too dense or too sparse, adapt in the next reply.

## Explanation Style

- Keep Chinese concise and direct.
- Optimize for comprehension, not textbook completeness.
- Focus on what the learner needs to understand the sentence.
- Do not dump every grammar point in the sentence.
- When a grammar item is basic and not blocking understanding, skip it.
- When a pronoun or omitted subject is important, state it plainly.
- Keep vocabulary and grammar notes attached to the relevant sentence instead of collecting them at the end.

## Grammar Selection

Prefer:

- N2/N3 grammar that changes sentence logic
- structures used in reading questions
- contrast, cause, condition, concession, judgment, and inferred meaning

Avoid by default:

- over-labeling trivial helper forms
- listing very basic grammar unless the user is confused by it
- turning one sentence into a full grammar note

## Output Pattern

Important: Format each original Japanese sentence in Markdown bold, e.g. `**原文句子**`, so it does not blend into the notes.
Important: Do not put furigana inside the bold original sentence. Put readings in the notes below, especially for N2/N3 words or words likely to block comprehension.

Use a structure close to this:

```markdown
**第1句**
**[原句，不加注音]**

- `词语（よみ）`：`[简明词义 / 文中义]`
- `[语法]`：`[简明说明]`

意思：
`[自然中文句意]`
```

When the user asks about a specific option or underlined part, answer that target first, then add the surrounding context if needed.

## Do Not Output

Do not append these archive-style sections unless the user explicitly asks for them:

- `重点语法`
- `重点单词`
- vocabulary tables
- grammar tables
- reusable sentence tables

If the user asks for those, use `$japanese-reading-archive` instead.

## Boundaries

- This skill explains the passage. It does not automatically update repository files.
- If OCR is unclear, say which part is uncertain instead of guessing.
- If the user later says “整理进阅读问题整理” or “归档”, hand off to `$japanese-reading-archive`.
