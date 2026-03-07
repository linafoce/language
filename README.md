# 日语笔记工作流（GitHub + Obsidian + 自动同步）

这个仓库用于替代受限在线笔记 App，实现：

- 你把 Gemini 生成的 Markdown 保存到本地
- Windows 自动提交并推送到 GitHub 私有仓库
- 在 Windows / iPhone 上用 Obsidian 阅读

## 目录约定

- `inbox/`：临时输入区（推荐先存这里）
- `courses/`：主线累计笔记（如 `N2.md`）
- `topics/`：专题笔记（单独文件）
- `scripts/`：自动同步脚本
- `logs/`：自动同步日志（自动生成）

## 快速开始

### 1) 配置 Git 仓库（首次）

如果你还没初始化：

```powershell
cd "C:\Users\xiang jun\git\notebook"
git init
git branch -M main
git remote add origin <你的GitHub私有仓库地址>
```

如果你是从 GitHub 克隆下来的仓库，可跳过这步。

### 2) 安装/确认 Git 账号信息

```powershell
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

### 3) 启动自动同步（当前会话）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\start-auto-sync.ps1"

# 停止当前仓库的后台同步进程
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\stop-auto-sync.ps1"
```

默认防抖为 15 秒。你保存 Markdown 后，脚本会自动执行：

`git add -A` -> `git commit` -> `git pull --rebase` -> `git push`

### 4) 设置开机自动运行（可选）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\install-login-task.ps1"
```

移除开机任务：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\uninstall-login-task.ps1"
```

## 你日常怎么用

1. 上课时把 Gemini 输出保存成 Markdown 到 `inbox/`。
2. 文件名建议：`YYYY-MM-DD-主题.md`（例如 `2026-03-07-授受动词.md`）。
3. 每周整理一次，把内容合并到 `courses/*.md` 或 `topics/*.md`。
4. 看日志：`logs/auto-sync.log`。

## iPhone 使用（Obsidian + Working Copy）

1. 在 iPhone 安装 Working Copy 与 Obsidian。
2. 在 Working Copy 克隆同一个 GitHub 私有仓库。
3. 在 Obsidian 打开该仓库目录作为 vault。
4. 日常阅读在 Obsidian，完成编辑后回到 Working Copy 执行 pull/push。

## 故障处理

- `pull --rebase` 冲突：日志会提示，需手动解决冲突后继续。
- 网络失败：本地提交会保留；你下次改动文件会自动重试推送。
- 没有 `origin` 远程：脚本会写日志并跳过推送，先执行 `git remote add origin ...`。
