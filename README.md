# 日语笔记工作流（Git + 自动同步 + GitHub Pages）

这个仓库用于替代受限笔记 App，实现：

- 你把 Gemini 生成的 Markdown 保存到本地目录
- Windows/macOS 自动提交并推送到 GitHub
- GitHub Pages 自动发布公开站点（含预渲染页面、搜索、最近更新）

## 目录约定

- `inbox/`：临时输入区（课堂即时落地）
- `courses/`：主线累计笔记（支持多层目录）
- `topics/`：专题笔记（支持多层目录）
- `scripts/`：自动同步与构建脚本
- `logs/`：本地同步日志

## 同步流程

自动同步脚本监听 `inbox/`、`courses/`、`topics/` 下的 `.md` 变化，触发：

`git add -A` -> `git commit` -> `git pull --rebase` -> `git push`

断网时本地提交会保留，下一次文件变化会自动重试推送。

### Windows

启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\start-auto-sync.ps1"
```

停止：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\stop-auto-sync.ps1"
```

### macOS

启动：

```bash
bash ./scripts/start-auto-sync.sh
```

停止：

```bash
bash ./scripts/stop-auto-sync.sh
```

## GitHub Pages（预渲染）

部署工作流：`.github/workflows/deploy-pages.yml`

每次推送后会执行：

1. 运行 `python scripts/build_site.py`
2. 递归扫描 `inbox/courses/topics` 的 Markdown
3. 生成：
   - `notes/<...>.html`（每篇笔记的预渲染页面）
   - `notes.json`（笔记索引）
   - `search-index.json`（全文检索索引源）
   - `recent.json`（最近更新 20 条）
4. 再由 GitHub Pages 发布静态站点

## 网站功能

- 首页：`index.html`
  - 全文搜索（lunr + CJK 包含匹配兜底）
  - 最近更新列表
  - 全部笔记列表
- 阅读页：预渲染 HTML（`notes/...`）
  - 目录模式切换：`H1` / `H1-H3`（`localStorage` 持久化）
  - 桌面右侧目录 + 手机抽屉目录
  - 目录高亮跟随并保持当前项可见
- 兼容入口：`viewer.html?file=...`
  - 自动重定向到对应预渲染页面（保留旧链接）

## 截图草稿自动化（v1）

目标：先生成草稿，再人工确认合并，避免直接污染主笔记。

### 1) 生成草稿

```bash
python scripts/generate_draft_from_images.py <folder> --topic <topic>
```

输出：`inbox/drafts/<date>-<topic>.md`

也可用包装命令：

- PowerShell: `.\scripts\generate-draft-from-images.ps1 <folder> [-Topic <topic>]`
- Bash: `bash ./scripts/generate-draft-from-images.sh <folder> [topic]`

### 2) 手动确认后合并

```bash
python scripts/merge_draft.py <draft-file> <target-file>
```

也可用包装命令：

- PowerShell: `.\scripts\merge-draft.ps1 <draft-file> <target-file>`
- Bash: `bash ./scripts/merge-draft.sh <draft-file> <target-file>`

## 多设备协作建议

- 多台电脑都克隆同一仓库
- 编辑前先 `git pull --rebase`
- 编辑后再 push
- 同一文件多端同时改会出现冲突，按 Git 正常流程手动解决

## 注意事项

- 这是公开 Pages，任何人都可访问站点内容
- 图片、附件建议使用相对路径并与 Markdown 一起纳入 Git
- 本仓库不依赖 Obsidian 付费同步
