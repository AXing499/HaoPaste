# Changelog

## 0.14.0 — 2026-11-11

### 中文

- 设置 → 通用 →「复制行为」新增「主面板复制后」，支持保持打开、立即收起、延迟 0.6 秒收起。
- 多文件条目可拖动文件图标一次拖出全部文件到 Finder 或其他应用。
- 新增 `make screenshots`，一键生成全部中英文 README 截图。
- 新增 `make verify-screenshots`，用固定时间和固定语言对比截图基线，帮助发现 UI 回归。
- 新增多文件拖拽测试；120 个 XCTest。

### English

- Added "After Copying from Panel" under Settings → General → Copy Behavior, with keep-open, hide-immediately, and hide-after-0.6-seconds options.
- Multi-file items can drag all files at once from the file icon into Finder or another app.
- Added `make screenshots` to regenerate all Chinese and English README screenshots.
- Added `make verify-screenshots` to compare deterministic renders against committed UI baselines.
- Added multi-file drag coverage; 120 XCTest cases.


## 0.13.22 — 2026-11-10

### 中文

- 修复主面板右侧信息与悬停操作图标在「无翻译按钮」条目上不对齐的问题，链接、文件等条目现在与文本条目使用同一操作列宽度。
- 同步更新中英文界面截图。

### English

- Fixed the trailing metadata and hover action alignment for rows without a translate action. Links, files, and other items now use the same action column width as text rows.
- Refreshed the Chinese and English screenshots.


## 0.13.21 — 2026-11-10

### 中文

- 设置 → 通用新增「应用语言」，可选择跟随系统 / 简体中文 / English；更改后可从设置卡片直接重启应用生效。
- 应用语言偏好会持久化保存，并新增对应回归测试。
- 英文版 README 全部改用英文界面截图，并新增英文截图资源。
- 英文界面将「识图并翻译」调整为更短的「OCR & Translate」，避免按钮截断。
- 自动化测试默认使用英文环境运行，并保留中文环境测试方式；共 119 个 XCTest。

### English

- Added App Language in Settings → General with System / 简体中文 / English options. Restart from the settings card to apply the change.
- Persisted the language preference and added regression coverage.
- Updated README.en.md to use English-UI screenshots and added the English screenshot assets.
- Shortened the English OCR action to "OCR & Translate" to prevent button truncation.
- CI now runs the 119 XCTest cases in English by default; the Chinese test environment remains documented.


## 0.13.20 — 2026-11-10

### 中文

- 新增完整英文界面：中文环境使用简体中文，英文环境使用英文，其他语言环境默认英文。
- 新增英文 README；GitHub Release 说明继续使用中英双语。
- DMG 安装背景与安装说明改为中英双语，保留「系统设置 → 隐私与安全性 → 安全性 → 仍要打开」的完整步骤。
- 补齐动态数量、单复数、相对时间、菜单、弹窗与辅助功能文案的本地化。
- 新增本地化回归测试，并修复格式化占位符与计数显示问题。
- 优化更新提示：按当前语言提取发布说明摘要，去除 Markdown 标记并限制长度。

### English

- Added a complete English UI. Chinese systems use Simplified Chinese, English systems use English, and all other languages fall back to English.
- Added an English README; GitHub Release notes remain bilingual.
- Made the DMG background and installation notes bilingual, including the full System Settings → Privacy & Security → Security → Open Anyway steps.
- Localized dynamic counts, plurals, relative times, menus, alerts, and accessibility labels.
- Added localization regression tests and fixed format placeholder and count display issues.
- Improved the update prompt with a localized plain-text summary of the release notes, without Markdown markers or excessive length.

## 0.13.19 — 2026-11-10

### 中文

- 挂架复制后可以保持展开、立即收起或延迟 0.6 秒收起。
- 新增「富文本只复制纯文本」设置，并在主面板和挂架右键菜单提供「复制为纯文本」。
- 复制为纯文本不会生成重复历史条目。

### English

- Shelf copies can keep the shelf open, hide immediately, or hide after 0.6 seconds.
- Added a "Rich text as plain text only" setting and "Copy as Plain Text" actions in the main panel and shelf context menus.
- Copying as plain text no longer creates duplicate history entries.

## 0.13.18 — 2026-11-10

### 中文

- 首次启动引导。
- 默认从 GitHub Releases 检查更新。
- 更新安装提示与发布流程。

### English

- First-launch onboarding.
- Update checks from GitHub Releases by default.
- Improved install guidance and release automation.
