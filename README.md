# 日语笔记工作流（GitHub + 自动同步 + GitHub Pages）

这个仓库用于替代受限笔记 App，实现：

- 你把 Gemini 生成的 Markdown 保存到本地
- Windows 自动提交并推送到 GitHub
- 用 GitHub Pages 公开网页阅读（不依赖 Obsidian 付费服务）

## 目录约定

- `inbox/`：临时输入区（推荐先存这里）
- `courses/`：主线累计笔记（例如 `N2.md`、`N3.md`）
- `topics/`：专题笔记
- `scripts/`：自动同步脚本
- `logs/`：自动同步日志（本地）

## 快速开始

### 1) Git 初始化与远程（已做可跳过）

```powershell
cd "C:\Users\xiang jun\git\notebook"
git init
git branch -M main
git remote add origin git@github.com:linafoce/language.git
```

### 2) 配置 Git 身份

```powershell
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

### 3) 启动自动同步（当前会话）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\start-auto-sync.ps1"
```

停止后台同步：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\stop-auto-sync.ps1"
```

默认防抖为 15 秒。保存后脚本自动执行：

`git add -A` -> `git commit` -> `git pull --rebase` -> `git push`

### 4) 设置开机自动运行（可选）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\install-login-task.ps1"
```

移除开机任务：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\uninstall-login-task.ps1"
```

## 开启 GitHub Pages（公开站点）

仓库已经包含：

- `index.md`：自动索引 `inbox/`、`courses/`、`topics/` 下的 Markdown
- `viewer.html`：网页渲染 Markdown
- `.github/workflows/deploy-pages.yml`：推送后自动发布

你只需要在 GitHub 网页做一次设置：

1. 进入仓库 `Settings` -> `Pages`
2. `Build and deployment` 的 `Source` 选择 `GitHub Actions`
3. 回到 `Actions` 等待 `Deploy GitHub Pages` 工作流成功
4. 打开站点（通常是 `https://linafoce.github.io/language/`）

## 日常使用

1. 上课时把 Gemini 输出保存为 Markdown 到 `inbox/`
2. 文件名建议：`YYYY-MM-DD-主题.md`
3. 每周整理一次，把内容合并到 `courses/*.md` 或 `topics/*.md`
4. 在 Pages 站点中阅读；日志看 `logs/auto-sync.log`

## 注意事项

- 你开启的是公开 Pages，任何人都可访问站点内容。
- 如果同一文件在多端同时修改，`pull --rebase` 可能出现冲突，需手动解决。
- 网络失败时本地提交会保留，后续变更会自动重试推送。
