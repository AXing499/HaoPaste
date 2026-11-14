# Changelog

## 0.17.0 — 2026-11-13

### 中文

- 在 macOS 26 上为挂架卡片、筛选条、划词翻译卡片和连续粘贴 HUD 接入系统 Liquid Glass 材质。
- 主面板改为整块玻璃，搜索 / 筛选 / 底栏位于玻璃上，每条历史记录也改为玻璃卡片；搜索框保持磨砂。
- 预览、翻译、OCR 弹层改为挂架同窗口内的浮层，挂架保持 key window，弹层整体使用活跃 Liquid Glass。
- 修复挂架弹层出现后无法点击、以及关闭弹层后挂架高度被压成 0、后续条目错位/无法交互的问题。
- 修复主面板玻璃行卡片左右边缘的暗边，让圆角过渡更平滑。
- 修复挂架命中区域上下颠倒导致的光标跳动、点击穿透和筛选后悬停卡住；卡片主体也使用手型光标。
- 改用 AppKit cursor rect 管理挂架光标，移除计时器反复强制设置光标造成的快速闪动。
- 筛选栏直接移入时显示手型光标；修复挂架窗口从忽略鼠标切换为接收鼠标时丢失进入事件、导致光标停留在箭头的问题。
- 分情况处理应用失焦：没有弹层时，挂架保留系统非活跃磨砂外观并按正常鼠标移开逻辑收回；预览 / 翻译 / OCR 弹层打开时，点击其他应用会立即收起挂架和全部弹层。
- 预览 / 翻译 / OCR 弹层的关闭、复制、翻译等按钮也统一为手型光标。
- 挂架筛选条保持紧凑宽度，通过更大的玻璃背板裁切实现通透效果；选中项使用半透明强调色；挂架操作条改为玻璃。
- 设置 → 通用 → 外观新增「Liquid Glass 效果」开关，默认开启；关闭后回退到现有轻量磨砂材质，降低 GPU 占用。
- 新增「玻璃通透度」三档设置：磨砂 / 标准 / 通透，默认通透；可调整玻璃的磨砂程度和透明感。
- 自动尊重「减弱透明度」与「提高对比度」辅助功能设置。
- 旧版 macOS 自动使用现有材质，不影响兼容性；截图渲染固定使用回退材质以保证基线稳定。
- 修复挂架首次出现时玻璃材质未立即生效、需要移动鼠标才刷新的问题。
- 启用 Liquid Glass 时，挂架展开会自动激活 HaoPaste，使玻璃立即使用活跃外观；收起后恢复原应用，不增加额外的用户开关。
- 修复打开预览、翻译或 OCR 详情面板后挂架玻璃变回磨砂的问题；详情面板不再抢占挂架的 key window。
- 挂架滚动到后面的卡片后，收起动画保持在当前位置，不再先跳回第一张再收起；下次展开仍从第一张开始显示。
- 设置窗口改为覆盖标题栏的整块 Liquid Glass，侧栏与设置卡片分层显示；标题栏透明并保留原生窗口按钮。
- 128 个 XCTest。

### English

- Adopted system Liquid Glass on macOS 26 for shelf cards, the filter bar, the selection translation card, and the paste-stack HUD.
- The main panel is now one glass surface with search, filters, and footer on glass; each history row is also a glass card, and the search field stays frosted.
- Preview, translation, and OCR popups now live inside the shelf window, so the shelf stays key and the whole popup uses active Liquid Glass.
- Fixed unresponsive shelf popups and the follow-up shelf collapsing to zero height after closing a popup.
- Fixed dark edge bands on the glass history cards for smoother rounded edges.
- Fixed inverted shelf hit testing that caused cursor flicker, click-through, and stuck hover after filtering; card bodies now use the pointing-hand cursor.
- Switched shelf cursors to AppKit cursor rects, removing timer-driven cursor reassertion that caused rapid flicker.
- The filter bar now shows the pointing hand when entered directly; fixed the lost enter event when the shelf panel switches from ignoring to accepting mouse events.
- Split app-deactivation behavior: without a popup the shelf keeps the system's inactive material and retracts through the normal mouse-away flow; with a preview, translation, or OCR popup open, switching apps dismisses the shelf and every popup immediately.
- Popup close/copy/translate buttons use the pointing hand cursor.
- The shelf filter keeps its compact width and uses a larger clipped glass backing for a clearer glass look; the selected pill is translucent, and the shelf action bar uses glass.
- Added a **Liquid Glass Effect** switch in Settings → General → Appearance, on by default. Turning it off falls back to the existing lightweight frosted material and reduces GPU usage.
- Added a three-level **Glass Transparency** setting: Frosted, Standard, and Clear (default). It controls how frosted or transparent the glass surfaces appear.
- Automatically respects Reduce Transparency and Increase Contrast accessibility settings.
- Older macOS versions keep the existing material automatically; screenshot rendering uses the fallback for stable baselines.
- Fixed the first shelf reveal keeping a stale material render until the pointer moved.
- With Liquid Glass enabled, the shelf activates HaoPaste on reveal so glass uses its active appearance, then restores the previous app when hidden. No extra user-facing switch is added.
- Fixed the shelf glass reverting to frosted material while preview, translation, or OCR panels are open; those panels no longer take the key window from the shelf.
- Preserved the shelf scroll position through the retract animation so it no longer jumps back to the first cards before hiding; each new reveal starts at the first item.
- The settings window now uses a Liquid Glass sheet that extends behind a transparent titlebar, with layered glass setting cards; the native window buttons remain.
- 128 XCTest cases.


## 0.16.0 — 2026-11-12

### 中文

- 新增「连续粘贴 / 粘贴栈」：在主面板多选条目后点击「连续粘贴」，按顺序逐条复制并粘贴；`⌃⌘V` 切换到下一项，底部 HUD 显示进度并可直接结束。
- 连续粘贴在辅助功能可用时自动发送 `⌘V`；未授权时只复制到剪贴板，并提示手动按 `⌘V`，不会强制要求权限。
- 新增「截图翻译」：通过 `⌃⌘S` 或菜单栏入口拖拽框选屏幕区域，本地 OCR 后可编辑文字并点击「翻译」；需要屏幕录制权限。
- 划词翻译卡片新增「替换原文」：将译文粘贴回来源应用，替换当前选中的文字。
- 新增「快捷键」设置页，可统一修改呼出面板、快捷翻译、连续粘贴下一项和截图翻译四个快捷键。
- 「替换原文」增加「替换时复制译文」开关，默认开启；关闭后只用于替换，并在粘贴完成后恢复原来的剪贴板内容。
- 修复挂架操作条的预览、翻译、提取文字按钮因缺少锚点或被挂架重新抢焦点而无法弹出/立即收起；修复连续粘贴在快捷键修饰键尚未释放时漏粘贴，以及截图选择光标不是十字的问题。
- 设置中补充说明：ad-hoc 签名版本每次更新后可能需要重新授予辅助功能和屏幕录制权限。
- 128 个 XCTest。

### English

- Added **Sequential Paste**: select multiple items in the panel and click **Paste Sequentially** to copy and paste them in order. Press `⌃⌘V` for the next item; a HUD shows progress and can end the queue.
- Sequential Paste sends `⌘V` automatically when Accessibility is available. Without permission it only copies each item and shows a manual `⌘V` hint instead of requiring permission.
- Added **Screenshot Translation**: press `⌃⌘S` or use the menu bar entry, drag to select a screen area, edit the local OCR result, then click Translate. Requires Screen Recording permission.
- Added **Replace Selection** to the selection translation card: pastes the translation back into the source app, replacing the selected text.
- Added a **Shortcuts** settings page for the panel, quick translation, paste-stack next item, and screenshot translation shortcuts.
- Added a **Copy translation when replacing** switch, on by default. When disabled, the translation is only used for replacement and the previous clipboard contents are restored afterwards.
- Fixed shelf action-bar preview, translate, and extract-text buttons failing because of a missing anchor or the shelf stealing key focus and immediately dismissing the detail panel. Also fixed sequential paste dropping items when the shortcut modifiers had not been released yet, and the screenshot region cursor not switching to a crosshair.
- Clarified in Settings that ad-hoc signed builds may require re-granting Accessibility and Screen Recording permission after each update.
- 128 XCTest cases.


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


## 0.15.1 — 2026-11-12

### 中文

- 划词图标改为自绘的方向性翻译气泡：保持 A / 文 正向，并根据图标相对选区的位置让气泡尾巴朝向下、上、左或右；优先显示在选区上方，空间不足时依次回退到下方、右侧或左侧。
- 划词翻译卡片中的原文现在可以直接编辑；修改后点击「翻译」或按回车重新翻译，`Shift+回车` 换行。原文未提交修改时译文会淡化，复制按钮暂时禁用。
- 调整图标比例，加宽 A 气泡、缩短尾巴，并修正点击图标偶发不弹出翻译的问题：忽略图标区域内的外部点击、开卡时短暂抑制重新检测选区，并把图标与卡片提升到 pop-up 窗口层级，避免被其他应用的选区弹窗拦截。
- 移除无效的手型光标尝试；保留悬停高亮与轻微缩放反馈。
- 新增方向性图标与四向布局测试；128 个 XCTest。

### English

- Replaced the fixed-tail SF Symbol with a custom directional translate glyph: the A / 文 bubbles stay upright while the tail points down, up, left, or right based on the icon's position relative to the selection. The icon prefers above, then below, right, and left.
- The source text in the selection translation card is now editable. Edit it and click **Translate** or press Return to translate again; press `Shift+Return` to insert a newline. While changes are unsubmitted, the translation dims and copy actions are disabled.
- Rebalanced the icon proportions, widened the A bubble, shortened the tail, and fixed an occasional failure where clicking the icon did not open translation: clicks inside the icon are no longer treated as outside interactions, selection checks are briefly suppressed while the card opens, and the icon/card now use a pop-up window level so other apps' selection popovers cannot intercept the click.
- Removed the ineffective pointing-hand cursor attempt; hover highlight and slight scaling remain.
- Added directional icon and four-way placement tests; 128 XCTest cases.


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
