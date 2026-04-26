---
name: japanese-reading-archive
description: Archive grammar points, vocabulary, and memorable expressions from Japanese reading passages into the repository's shared review file with low-noise tables. Use when the user asks to归档阅读材料里的语法和单词, 把当前阅读的难点追加到统一文件, or maintain `content/word/阅读问题整理.md` while keeping entries concise and reusable.
---

# Japanese Reading Archive

Use this skill when the user wants to extract reusable study items from a Japanese reading passage after or during reading analysis.

The target file in this repository is:

- `content/word/阅读问题整理.md`

## Core Goal

Turn one reading passage into a compact review entry with:

- a passage title section
- a grammar table
- a vocabulary table
- an optional short table of memorable expressions

The output is for later review, not for full teaching notes.

## Workflow

1. Read only the passage or excerpt relevant to the current user request.
2. Select grammar and words that are worth reviewing. Do not try to exhaustively harvest everything.
3. Prefer items that are mid-frequency, easy to forget, easy to misread, or important to understanding the passage.
4. Append the new passage as one section in `content/word/阅读问题整理.md` unless the user asks for another destination.
5. Keep the file usable as a long-running accumulation file across many readings.
6. Do not scan the full archive for duplicates by default.

## Hard Rules

- Do not add JLPT level labels.
- Use tables by default.
- Keep explanations short.
- Do not over-split grammar into tiny fragments unless the fragment is itself worth learning.
- Do not add romaji.
- Use hiragana for readings.
- Preserve the Japanese expression as it appears in context when possible.
- If OCR or source text is uncertain, mark it instead of guessing.

## Duplicate Handling

- Treat each passage section as mostly independent.
- Avoid duplicates within the new section itself.
- Do not read or scan the whole `content/word/阅读问题整理.md` only to check whether a word or grammar point appeared before.
- If the current context already makes a duplicate obvious, it is fine to skip it.
- If the user explicitly asks to dedupe against the existing archive, then check the file and dedupe.

## Default Section Format

Use this structure for each passage:

```markdown
## [编号]. [标题]

### 语法

| 语法 | 原文 | 含义 |
| :-- | :-- | :-- |

### 单词

| 单词 | 读音 | 词性 | 文中义 |
| :-- | :-- | :-- | :-- |

### 可直接记的句子

| 表达 | 中文 |
| :-- | :-- |
```

## Selection Guidance

### Grammar

Prefer:

- patterns that affect sentence interpretation
- structures the learner is likely to want to review later
- forms that are reusable beyond the current passage

Avoid by default:

- extremely basic grammar
- grammar labels that are too broad to be helpful unless the user prefers broad labels
- listing every helper form in a long sentence

### Vocabulary

Prefer:

- words central to passage meaning
- words with non-obvious readings
- words that are useful in future readings

Avoid by default:

- very basic everyday words unless the user specifically asks to include them
- words whose meaning is already obvious from Chinese characters and context

## Writing Style

- Keep Chinese concise and direct.
- Optimize for scanning and later review.
- Do not turn the file into a textbook.
- When the user asks only for整理, do not add long sentence-by-sentence analysis.
