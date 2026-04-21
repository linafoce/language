---
name: japanese-reading-issue-log
description: Consolidate grammar points, vocabulary, and memorable expressions from Japanese reading passages into the repository's shared review file with low-noise tables and de-duplication. Use when the user asks to从阅读材料里整理语法和单词, 把当前阅读的难点追加到统一文件, 去重已有条目, or maintain `content/word/阅读问题整理.md` while keeping examples concise and reusable.
---

# Japanese Reading Issue Log

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

## Hard Rules

- Do not add JLPT level labels.
- Use tables by default.
- Keep explanations short.
- Do not over-split grammar into tiny fragments unless the fragment is itself worth learning.
- Do not add romaji.
- Use hiragana for readings.
- Preserve the Japanese expression as it appears in context when possible.
- If OCR or source text is uncertain, mark it instead of guessing.

## De-duplication Rules

- Treat `content/word/阅读问题整理.md` as a cumulative review log, not a per-article archive.
- Before adding a new item, check whether the same grammar point or word is already present in the file.
- If the same item already exists with the same core meaning, do not create a duplicate row just because the source article is different.
- When a repeated item has a genuinely useful new example, prefer updating the existing row later with another example rather than duplicating the item inside the new section.
- If the same form appears but the meaning or usage is materially different, it may be added as a separate item with a clearly differentiated gloss.
- If the user explicitly wants per-article independence, follow that request even if it creates repetition.

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
