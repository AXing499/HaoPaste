# Changelog

## 0.15.0 — 2026-11-12

### 中文

- 新增实验性「划词翻译」，默认关闭，可在设置 → 智能中启用。
- 鼠标划词后显示翻译图标，点击后在选区附近显示紧凑翻译卡片。
- 通过 Accessibility 读取选中文本，不模拟 ⌘C、不自动复制，也不会抢走用户的复制操作。
- 全屏应用、安全输入状态、隐私排除应用和 HaoPaste 自身不触发；当前仅支持鼠标划词。
- 设置中增加辅助功能权限说明与授权入口，并对 ad-hoc 重装后的旧权限给出提示。
- 划词图标改为无底色、无边框的更小 `translate` 图形，改用原生符号渲染以提升 Retina 清晰度；扩大透明点击区域，避免悬停缩放被裁剪，并增加回弹出现 / 消失、悬停和按压反馈。
- 划词图标在鼠标悬停时暂停自动消失，移开鼠标后 2 秒再消失；悬停时高亮并轻微放大，明确表示可以点击。受 macOS 非激活浮层限制，不显示手型光标。
- 图片条目的快捷操作改为「提取文字」；识图窗口内再点击「翻译」，不再默认识图后自动翻译。
- 划词卡片、预览、识图、批量识图与翻译弹框统一使用一致的不透明系统表面，划词卡片与识图弹框颜色完全一致；划词卡片改用系统原生窗口阴影，四周边缘更平滑。
- 扩大 Accessibility 选区读取范围，兼容更多 Chromium / Electron 和文档类应用。
- 设置页与划词翻译改为无提示凭证检查，避免打开设置或划词时反复弹出钥匙串密码框。
- 新增划词卡片截图与布局测试；124 个 XCTest。

### English

- Added experimental Selection Translation, off by default and enabled in Settings → Smart.
- Selecting text with the mouse shows a translate icon; clicking it opens a compact translation card near the selection.
- Selected text is read through Accessibility without simulating ⌘C, copying automatically, or stealing copy operations.
- Full-screen apps, secure input, excluded apps, and HaoPaste itself are skipped. Mouse selection is supported in this version.
- Added Accessibility permission guidance and a shortcut to System Settings, including guidance for stale ad-hoc approvals.
- Switched the selection icon to a smaller, chrome-free native `translate` glyph rendered as a native symbol for sharper Retina output; enlarged the transparent hit area so hover scaling never clips, and added spring appearance / dismissal, hover, and press feedback.
- The translation icon now stays visible while the pointer hovers over it and disappears 2 seconds after the pointer leaves; it highlights and scales slightly to signal that it is clickable. A pointing-hand cursor is not shown because macOS does not apply cursor changes from inactive non-activating panels.
- Changed the image quick action to **Extract Text**; translation is now a separate action in the OCR window instead of running automatically after recognition.
- Unified the selection card, preview, OCR, batch OCR, and translation panes on the same opaque system surface, so the selection card and OCR pane match exactly; the selection card now uses the native window shadow for smooth edges.
- Expanded Accessibility selection lookup for more Chromium / Electron and document apps.
- Changed settings and selection translation to use non-prompting credential checks, avoiding repeated Keychain password dialogs.
- Added selection-card screenshots and placement tests; 124 XCTest cases.


## 0.14.2 — 2026-11-11

### 中文

- 复制成功后，主面板条目与挂架卡片显示勾选弹跳和轻微缩放反馈。
- 置顶 / 取消置顶增加 SF Symbol 回弹反馈。
- 主面板打开增加 0.98 → 1.0 的短弹簧缩放，保留原有上滑淡入。
- 挂架新卡片落入使用更轻快的弹簧回弹。
- 新增动效均尊重「减弱动态效果」；截图渲染可关闭动画以保证基线稳定。

### English

- Added a checkmark bounce and subtle scale feedback after copying in the panel and shelf.
- Added SF Symbol bounce feedback for pin / unpin.
- Added a short 0.98 → 1.0 spring scale when opening the panel, alongside the existing slide and fade.
- Gave new shelf cards a lighter spring landing animation.
- All new motion respects Reduce Motion; screenshot renders can disable animations for stable baselines.


## 0.14.1 — 2026-11-11

### 中文

- 修复挂架滚动指示器的轨道与滑块粗细不一致问题，滚动条更清晰。
- 修复翻译引擎优先级的上下箭头在不同配置状态下左右不对齐的问题，使用固定操作列宽。
- 修复截图渲染时读取 Keychain 可能卡住的问题；Debug 截图改用内存凭证，并用占位 Azure 配置展示混合状态。
- 重新生成中英文截图。

### English

- Fixed the shelf scroll indicator track and thumb thickness mismatch for a clearer scrollbar.
- Fixed horizontal misalignment of the translation engine priority arrows across configured and unconfigured rows by using fixed action columns.
- Fixed screenshot renders hanging on Keychain access; Debug renders now use in-memory credentials with a placeholder Azure configuration.
- Regenerated the Chinese and English screenshots.


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
