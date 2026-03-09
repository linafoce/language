# 日语笔记仓库

这个仓库现在只围绕两件事：

- 维护 `content/` 里的 Markdown 笔记
- 自动同步到 GitHub，并生成 GitHub Pages 网站

## 目录结构

- `content/`：唯一主笔记目录
- `drafts/`：草稿、试排版文件、历史备份
- `tools/`：项目功能脚本
- `ops/`：PowerShell / shell 命令入口
- `notes/`：预渲染后的静态页面产物
- `logs/`：本地同步日志

## 自动同步

自动同步默认监听：

- `content/`
- `drafts/`

触发流程：

`git add -A` -> `git commit` -> `git pull --rebase` -> `git push`

### Windows

启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\ops\sync\start-auto-sync.ps1"
```

停止：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\ops\sync\stop-auto-sync.ps1"
```

开机自动启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\ops\sync\install-login-task.ps1"
```

移除开机任务：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\ops\sync\uninstall-login-task.ps1"
```

### macOS

启动：

```bash
bash ./ops/sync/start-auto-sync.sh
```

停止：

```bash
bash ./ops/sync/stop-auto-sync.sh
```

## 网站构建

GitHub Pages 工作流会运行：

```bash
python tools/site/build_site.py
```

构建时会扫描 `content/`，并生成：

- `notes/<...>.html`
- `notes.json`
- `search-index.json`
- `recent.json`

兼容入口仍然保留：

- `viewer.html?file=content/N2.md`
- 旧链接如 `viewer.html?file=courses/N2.md` 也会自动重定向

## 截图草稿

从截图生成草稿：

```bash
python tools/drafts/generate_draft_from_images.py <folder> --topic <topic>
```

默认输出到：

`drafts/`

命令入口：

- PowerShell: `.\ops\drafts\generate-draft-from-images.ps1 <folder> [-Topic <topic>]`
- Bash: `bash ./ops/drafts/generate-draft-from-images.sh <folder> [topic]`

人工确认后合并草稿：

```bash
python tools/drafts/merge_draft.py <draft-file> <target-file>
```

命令入口：

- PowerShell: `.\ops\drafts\merge-draft.ps1 <draft-file> <target-file>`
- Bash: `bash ./ops/drafts/merge-draft.sh <draft-file> <target-file>`

建议把主笔记继续合并回 `content/`。

## 说明

- 这个仓库的主内容只有 `content/`
- `drafts/` 不会上站，只用于过渡和存档
- skill 相关内容不是本仓库主流程的一部分
