# Changelog

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
