# 架构与技术说明

## 1. 项目定位

HaoPaste 是本地优先的 macOS 剪切板管理器，目标是在 Raycast / Paste 级别的交互质感下，保持原生、低依赖、可预测的行为。

核心原则：

1. **键盘优先**：不用离开键盘即可搜索、选择、复制。
2. **原生语义**：系统材质、系统强调色、SF Symbols、连续圆角、系统字体。
3. **本地优先**：无账号、无遥测，历史只存在本机；默认不联网，在线翻译仅在用户操作时按需发送当前文本。
4. **低权限**：核心功能不申请辅助功能、屏幕录制等敏感权限；可选的划词翻译按需申请辅助功能。
5. **可维护**：模块边界清晰，无第三方运行时依赖。

## 2. 技术栈

| 领域 | 技术 |
| --- | --- |
| 语言 | Swift（工程使用 Swift 5 语言模式，Swift 6.3 编译器） |
| 最低系统 | macOS 14.0 |
| UI | SwiftUI（`@Observable`、`@Bindable`、`@FocusState`、`ImageRenderer` 调试） |
| 窗口 / 状态栏 | AppKit：`NSPanel`、`NSHostingView`、`NSStatusItem`、`NSMenu` |
| 全局快捷键 | Carbon `RegisterEventHotKey`，快捷键可配置 |
| 设置存储 | `UserDefaults` + `@Observable AppSettings` |
| 开机启动 | ServiceManagement `SMAppService.mainApp` |
| 剪贴板 | `NSPasteboard.general` + `changeCount` 轮询 |
| 去重 | CryptoKit `SHA256` |
| 图片处理 | ImageIO / CoreGraphics / AppKit，PNG 归一化 + 缩略图 |
| 持久化 | Foundation `JSONEncoder` / `JSONDecoder` + 文件系统 |
| 翻译 | 可插拔 `TranslationProvider`，`URLSession` + HTTPS |
| 文字识别 | Vision `VNRecognizeTextRequest`（本地、离线） |
| 翻译凭证 | macOS Keychain（`Security.framework`） |
| 数据目录 | `~/Library/Application Support/HaoPaste/` |
| 工程生成 | XcodeGen（`project.yml`） |
| 构建 / 发布 | `xcodebuild`、Makefile、`hdiutil`、`codesign` |
| 安装包 | DMG（.app + Applications 快捷方式） |

无第三方 Swift Package 依赖。

## 3. 运行时结构

```text
NSApplication (accessory / LSUIElement)
│
├── AppDelegate
│   ├── ClipboardManager ─────── ClipboardMonitor
│   │        │                        │
│   │        └── ClipboardStore        └── NSPasteboard.general
│   │             ├── history.json
│   │             └── Images/
│   │
│   ├── QuickTranslationPanelController
│   │   └── TranslationService (quick instance, shared settings/consent)
│   │
│   ├── ClipboardShelfController
│   │   ├── ClipboardShelfPanel (NSPanel, nonactivating, transparent)
│   │   └── NSHostingView<ClipboardShelfView>
│   │
│   ├── TranslationService
│   │   ├── TranslationSettingsStore (UserDefaults)
│   │   ├── KeychainTranslationCredentialStore
│   │   └── TranslationProviderFactory
│   │        └── Google / Bing / DeepL / Azure / 百度 / Google Cloud
│   │
│   ├── OCRService
│   │   └── VisionTextRecognizer (Vision)
│   │
│   ├── PanelController
│   │   ├── ClipboardPanel (NSPanel, borderless, floating)
│   │   ├── NSHostingView<ContentView>
│   │   ├── PanelViewState
│   │   └── NSEvent local key monitor
│   │
│   ├── StatusBarController
│   │   └── NSStatusItem + NSMenu
│   │
│   ├── GlobalHotKey
│   │   └── Carbon RegisterEventHotKey (default ⌥⌘V, configurable)
│   │
│   └── SettingsWindowController
│       └── SettingsView (general / history / snippets / privacy / about)
│           ├── AppSettings (UserDefaults + SMAppService)
│           └── SnippetManager ── SnippetStore (snippets.json)
│
ContentView / ItemRowView / SnippetRowView (SwiftUI)
```

应用没有主窗口，采用 `.accessory` 激活策略（并设置 `LSUIElement`），启动后驻留菜单栏。

## 4. 模块职责

### App

| 文件 | 职责 |
| --- | --- |
| `HaoPasteApplication.swift` | AppKit 入口，持有 AppDelegate，设置 accessory 激活策略 |
| `AppDelegate.swift` | 依赖装配、主菜单、首次启动展示、应用代理生命周期 |
| `PanelController.swift` | 无边框悬浮面板的创建 / 定位 / 显隐动画、键盘事件、焦点恢复、自动翻译最新记录、主面板复制后行为 |
| `OnboardingWindowController.swift` | 首次启动欢迎引导，可从设置 → 关于再次打开 |
| `UpdateChecker.swift` | 读取 JSON 更新清单、版本比较和更新提示 |
| `QuickTranslationPanelController.swift` | `⌥⌘T` 快捷翻译卡片：读取剪贴板、定位、键盘与焦点恢复；也支持从挂架传入文本与锚点 |
| `ShelfPreviewPanelController.swift` | 屏幕中央的预览卡片：复用预览内容，使用原生窗口阴影 |
| `ShelfOCRPanelController.swift` | 屏幕中央的识图卡片：独立 OCR 服务、翻译回调与片段保存 |
| `ShelfDetailPanel.swift` | 预览 / 识图卡片使用的透明非激活浮动面板 |
| `ClipboardShelfController.swift` | 顶部挂架：30Hz 鼠标轮询、展开 / 收起、菜单栏与全屏抑制、卡片命中与点击穿透 |
| `ClipboardShelfPanel.swift` | 透明、非激活的挂架 `NSPanel`，跨 Space 显示且不抢焦点 |
| `StatusBarController.swift` | 菜单栏图标、左键呼出面板、右键菜单、暂停、清空、退出 |
| `GlobalHotKey.swift` | Carbon 系统级快捷键注册和事件分发，失败时抛出冲突错误 |
| `SettingsWindowController.swift` | 设置窗口托管与激活 |

### Services

| 文件 | 职责 |
| --- | --- |
| `ClipboardMonitor.swift` | 350ms 轮询 `changeCount`，过滤隐藏类型，生成 `CapturedClipboard` |
| `ClipboardManager.swift` | 核心业务：去重、置顶、删除、清空、复制回剪贴板、FIFO 裁剪、历史容量 |
| `AppSettings.swift` | 用户偏好、快捷键、历史上限、登录项状态、排除应用、图片记录开关、挂架开关 / 位置 / 加载数量 |
| `ClipboardStore.swift` | JSON 历史记录、图片资产、防抖写入、目录管理、导入图片资产 |
| `SnippetStore.swift` | `snippets.json` 持久化 |
| `SnippetManager.swift` | 片段 CRUD、过滤、备份合并与可观察状态 |
| `HistoryArchiveService.swift` | zip 备份导出、解包、manifest 与合并导入（含片段） |
| `ContentClassifier.swift` | 文本、URL、HEX、JSON、代码的启发式分类 |
| `ContentHasher.swift` | 加类型盐的 SHA-256 去重指纹 |
| `ImageProcessor.swift` | 解码、PNG 归一化、获取像素尺寸、生成最大 560px 缩略图 |
| `TranslationService.swift` | 翻译状态、引擎优先级、自动回退、授权、长文本分块与内存缓存 |
| `TranslationSettingsStore.swift` | 目标语言、引擎顺序、启用状态与授权持久化 |
| `TranslationCredentialStore.swift` | API 凭证的 Keychain 读写（含测试用内存实现） |
| `QuickTranslationSupport.swift` | 自动翻译策略、剪贴板文本读取 |
| `Translation/` | Google / Bing / DeepL 非官方通道，Azure / DeepL API / 百度 / Google Cloud 官方适配 |
| `OCRService.swift` | Vision 本地 OCR、单张 / 批量识别、语言选择、结果编辑与状态管理 |
| `OCRCacheStore.swift` | 按图片哈希与识别语言持久化 OCR 文字（`OCR/`） |
| `ItemPreview.swift` | 预览文本构建：RTF / HTML 归一化、字体大小收敛、12 万字符上限 |
| `ItemDragProvider.swift` | 为文本 / 图片 / 单文件构建 `NSItemProvider`，附带 RTF / HTML 数据 |
| `MultiFileDragHandle.swift` | 多文件条目使用 `NSDraggingSession` 一次拖出全部文件 |
| `MergedContentBuilder.swift` | 多选合并规则：文本换行、文件 URL、混合路径与图片限制 |
| `ImageSavePanel.swift`（Utilities） | 共享的 PNG 另存为流程与错误提示 |
| `Localization.swift`（Utilities） | 系统语言选择、`L()` 文案查表与格式化 |
| 富文本 | `RichTextPayload` + `RichText/<id>.json`（RTF / HTML 原始数据） |

### UI / State

| 文件 | 职责 |
| --- | --- |
| `ContentView.swift` | 面板布局：搜索栏、分类、数量、列表、页脚 |
| `ItemRowView.swift` | 条目卡片：图标 / 缩略图、徽章、来源、时间、快捷复制、悬停预览 / 置顶 / 删除、拖拽 |
| `PreviewOverlayView.swift` | 预览卡片：图片棋盘格、全文 / 富文本、颜色色块、文件列表、拖拽与动作 |
| `MultiSelectionBar.swift` | 多选浮动操作条：已选数量、合并复制、取消与不支持提示 |
| `TranslationPaneView.swift` | 翻译面板：语言 / 引擎切换、授权、结果、复制与保存片段 |
| `ClipboardShelfView.swift` | 顶部挂架：晾衣绳、卡片布局、全部 / 文本 / 图片筛选与命中区域上报 |
| `ShelfCardView.swift` | 挂架卡片：文本 / 图片 / 文件 / 颜色、悬停抬升、点击复制与「已复制」反馈 |
| `OCRPaneView.swift` | 单张识图面板：原图缩略、可编辑文字、复制 / 翻译 / 保存片段 |
| `BatchOCRPaneView.swift` | 批量识图面板：逐张结果、编辑 / 复制 / 翻译、复制全部 |
| `TranslationSettingsPage.swift` | 设置「智能」页：引擎优先级、凭证配置与测试 |
| `FilterTabsView.swift` | 胶囊分类按钮与 matched geometry 滑动选中态 |
| `EmptyStateView.swift` | 空历史 / 无搜索结果状态 |
| `PanelFooterView.swift` | 监听状态与键盘提示 |
| `PanelViewState.swift` | 搜索、分类、单选 / 多选、锚点、预览状态、焦点触发器 |
| `HotKeyConfiguration.swift` | Carbon 键码 / 修饰符、显示文案与校验 |
| `ClipboardShelfLayout.swift` | 挂架几何：卡片宽度、滚动上限、可见范围、绳线弧度、菜单栏 / 侧边展开区域、顶 / 侧面板布局、全屏检测与命中判定 |
| `ClipboardShelfEdge.swift` | 挂架位置：顶部 / 左侧 / 右侧 |
| `ClipboardShelfFilter.swift` | 挂架筛选：全部 / 文本（含代码、链接、颜色）/ 图片 |
| `Snippet.swift` | 可复用文本片段模型 |
| `TrashedClipboardItem.swift` | 最近删除条目与删除时间 |
| `SnippetRowView.swift` | 面板片段列表行，右键支持编辑 / 删除 |
| `TrashRowView.swift` | 最近删除列表行，支持恢复与彻底删除 |
| `RichTextPayload.swift` | RTF / HTML 富文本缓存模型 |
| `ExcludedApplication.swift` | 按应用的隐私排除规则 |
| `Theme.swift` | 圆角、间距、弹簧动效、描边颜色、字体辅助 |
| `HexColor.swift` | HEX 解析、色块、RGB / HSL 表示 |
| `SearchMatcher.swift` | 中文 / 拼音 / 模糊搜索与相关性评分 |
| `SettingsView.swift` | 设置窗口：通用、历史、片段、隐私、关于 |
| `SnippetEditorSheet.swift` | 片段新建 / 编辑表单（位于 SettingsView.swift，设置与面板共用） |
| `ShortcutRecorderView.swift` | 快捷键捕获与冲突错误展示 |

## 5. 数据模型

```swift
enum ClipboardItemType: String, Codable {
    case text, image, file, colorHex, url, code
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    let id: UUID
    var type: ClipboardItemType
    var content: String          // 文本原文 / 图片文件名
    var plainText: String        // 搜索与纯文本输出
    var isPinned: Bool
    var createdAt: Date
    var sourceApp: SourceApplication?
    var contentHash: String      // SHA-256(type + payload)
    var imageFileName: String?
    var thumbnailFileName: String?
    var imageDimensions: ImageDimensions?
    var filePaths: [String]?     // .file 引用一个或多个路径
    var richTextFileName: String? // RichText 缓存文件名
}
```

- 图片的 `content` 是磁盘文件名，不是位图本身；文件条目的 `filePaths` 保存文件 / 文件夹路径引用，不复制文件本体。
- `sourceApp` 记录复制发生时的最前方应用（`NSWorkspace.frontmostApplication`），排除 HaoPaste 自身。
- `contentHash` 用于跨会话去重。
- JSON 日期使用 Unix 毫秒，写入使用原子写；连续变化做 400ms 防抖。

## 6. 关键流程

### 6.1 监听与入库

1. `ClipboardMonitor.start()` 启动一个主线程 Task，每 350ms 读取 `NSPasteboard.general.changeCount`。
2. `changeCount` 不变则跳过；变化时读取 `types`。
3. 若包含 `org.nspasteboard.ConcealedType`、`TransientType`、`AutoGeneratedType`、常见密码管理器前缀，直接忽略。
4. 先读取文件 URL（支持 Finder 多选），没有文件时再尝试图片（PNG / TIFF），最后读取字符串并分类；文本会同时读取 RTF / HTML，单格式超过 2MB 时丢弃该格式。
5. 计算 SHA-256；与已有项比较：
   - 命中：更新时间、更新来源、保留置顶状态并移到内部数组顶部；
   - 未命中：创建记录；图片写入 PNG 和缩略图。
6. 若未置顶记录超过设置上限，按 `createdAt` 从旧到新淘汰（置顶永不淘汰）。
7. 通过 400ms 防抖将整个历史写入 JSON。

### 6.2 复制历史条目

1. `manager.copyToPasteboard(item)` 清空系统剪贴板并写入字符串或 PNG 数据。
2. 写入后立即同步 `changeCount`，避免自身写入被监控器再次采集。
3. 刷新该条目的 `createdAt`，使下次呈现时更靠前。
4. 面板关闭并恢复此前的前台应用；用户回到目标应用按 `⌘V`。

### 6.3 面板呈现

1. 全局快捷键 / 菜单栏左键 / 应用重新打开触发 `PanelController.show()`。
2. 根据鼠标所在屏幕居中、靠上定位；窗口尺寸为 720×560，四周不再保留阴影留白。
3. 记录当前前台应用；面板使用 `.nonactivatingPanel` + `orderFrontRegardless`，确保即使不抢占前台应用也能成为 key window。
4. SwiftUI 搜索框获取焦点；列表选中第一项。
5. 点击面板外侧或其他应用时关闭。关闭时按需重新激活之前的前台应用，避免焦点丢失。

### 6.4 设置与登录项

- 通用页：登录时自动启动（`SMAppService.mainApp`）、全局快捷键录制、暂停监听。
- 历史页：未置顶记录上限（100 / 200 / 500 / 1000）、清空未置顶 / 全部、在 Finder 中显示数据目录，以及导出 / 导入 `.zip` 备份。
- 片段页：创建 / 编辑 / 删除片段；面板提供独立「片段」标签，支持「新建片段」、文本条目右键「保存为片段」、片段行右键编辑 / 删除、搜索、键盘选择和快速复制。打开面板内编辑器时会暂停 `PanelController` 的键盘拦截，让输入框获得完整键盘事件。
- 首次启动：`showLaunchExperienceIfNeeded` 在首次启动时显示 `OnboardingWindowController`，完成或关闭后打开主面板；`hasCompletedOnboarding` 只写入一次，设置 → 关于的「查看首次引导」通过通知重新打开。
- 更新检查：`UpdateChecker` 默认请求 `https://api.github.com/repos/AXing499/HaoPaste/releases/latest`，兼容 GitHub Releases API 和自定义 JSON 清单；版本比较会去掉前缀 `v`。启动后最多每 24 小时自动检查一次，手动检查在设置 → 关于中执行。检查到新版本只显示提示并打开下载链接，不做自动下载或替换安装。
- 最近删除：`ClipboardManager.delete` 把条目移入 `trashedItems` 而不是立刻删除资源；`trash.json` 记录条目和 `deletedAt`，历史与最近删除分两个 JSON 保存。`ClipboardFilter.trash` 在面板中显示最近删除标签，`TrashRowView` 提供恢复 / 彻底删除。`purgeExpiredTrash` 在启动、打开面板和修改保留时间时清理过期条目，保留时间由 `AppSettings.trashRetentionDays` 控制。
- 隐私页：图片记录开关、按应用排除列表（通过 `NSOpenPanel` 选择 `.app`，记录 Bundle ID / 名称）。
- 设置保存在 `UserDefaults`；应用启动时读取并将历史上限同步给 `ClipboardManager`。
- 历史上限调低后立即执行一次 FIFO 裁剪，置顶记录始终保留。
- 排除规则在 `ClipboardMonitor` 读取剪贴板内容之前判断，从源头避免被排除应用的复制内容进入处理流程；`ClipboardManager` 再做一次防御性过滤。
- 登录项状态以 `SMAppService.mainApp.status` 为准；如果系统要求批准，设置页提供打开系统登录项设置的入口。

### 6.5 备份与迁移

- 导出包结构：`HaoPasteBackup/manifest.json`、`history.json`、`snippets.json`、`Images/`、`RichText/`。
- manifest（schema v3）记录应用版本、导出时间、记录数、图片数、片段数和富文本数；`history.json` / `snippets.json` 使用毫秒时间戳编码。
- 富文本缓存导入时复制为新文件名，缺失缓存会降级为纯文本。
- 旧版 schema 没有 `snippets.json` 时按空片段导入；新版片段导入按 id / 内容去重合并。
- 使用 `/usr/bin/ditto` 打包 / 解包，无第三方依赖。
- 导入为**合并**语义：按 `contentHash` 去重；导入项若为置顶而本地项未置顶，会合并置顶状态。
- 图片导入会生成新的本地文件 ID 与缩略图，避免覆盖现有资产；重复导入不会重复入库。
- 导入后按当前历史上限裁剪，置顶记录保留；备份包未加密，包含完整剪贴板内容与片段。

### 6.6 快捷动作

- 行内右键菜单按类型提供动作：预览、URL 打开 / 复制 Markdown、文件打开 / Finder 定位、图片保存、颜色复制 HEX / RGB / HSL。
- 动作写回剪贴板时复用 `ClipboardManager.copyTextToPasteboard`，会同步 `changeCount`，不会产生额外的历史条目。
- 文件 / URL 直接交给 `NSWorkspace` 打开；图片保存使用 `NSSavePanel` 写出原始 PNG。

### 6.7 预览与拖拽

- 预览状态保存在 `PanelViewState.previewingItemID`，`ContentView` 将其解析为当前可见条目并叠加 `PreviewOverlayView`。
- `⌘Y`、悬停眼睛按钮、右键「预览」都能打开；预览中 `↑` `↓` 在可见条目间切换，`↵` 复制并关闭，`esc` 返回列表。
- 图片预览读取原始 PNG，用棋盘格展示透明区域；文本预览优先解析 RTF，其次 HTML，最终回退纯文本。
- 富文本在显示前会统一前景色、移除背景色，并把字号限制在 10–20pt，避免网页粘贴内容在深色模式下不可读。
- 超过 12 万字符的文本只渲染前缀并提示，复制仍使用完整内容。
- 列表行通过 `.onDrag` 提供 `NSItemProvider`：文本附带纯文本 / RTF / HTML，图片附带 PNG 数据与文件 URL，单文件条目附带文件 URL。
- 预览中的图片和文件行也可拖拽；多文件条目暂不支持整体拖拽。

### 6.8 多选与合并

- 多选状态由 `PanelViewState.selectedIDs` 与 `selectionAnchorID` 管理；单选仍使用 `selectedID`，两者在 UI 中统一通过 `isItemSelected` 判断。
- `⌘`-点击切换条目，`⇧`-点击按锚点选择连续范围；`⇧↑` / `⇧↓` 移动焦点并扩展范围，`⌘⇧A` 全选当前可见结果，`esc` 优先取消多选。
- 选中 2 条以上时，列表底部浮现 `MultiSelectionBar`；`↵` 或「合并复制」执行合并，结果写入剪贴板后关闭面板。
- `MergedContentBuilder` 按可见顺序合并：文本类用换行连接；全部为文件时输出多个文件 URL；文本与文件混合时文件以路径形式追加。
- 图片暂不支持合并，操作条会禁用主按钮并显示原因。
- 合并写入会同步 `changeCount`，因此不会生成新的历史记录，也不会改变原条目的时间。

### 6.9 翻译

- 翻译入口仅对 `.text` / 富文本开放：`⌘T`、预览底部「翻译」、右键「翻译…」。
- `TranslationService` 读取 `TranslationSettingsStore` 的引擎顺序，依次尝试已启用且已配置的 Provider；单个 Provider 失败会自动回退到下一个。
- 首次使用在线引擎时需要显式授权，授权按 Provider 记录；新增引擎会再次询问。
- 文本按 Provider 的 `maxCharactersPerRequest` 分段翻译，再按换行拼接；翻译结果只做内存 LRU 缓存（50 条）。
- 本地用 `NLLanguageRecognizer` 检测源语言；若原文已是目标语言，本次翻译会尝试切换中英方向。
- 复制译文复用 `ClipboardManager.copyTextToPasteboard`，同步 `changeCount`，不会生成历史记录。
- 快捷翻译卡片 `QuickTranslationPanelController` 使用独立的 `TranslationService` 状态，但共享 `TranslationSettingsStore` 与 Keychain 凭证；读取 `NSPasteboard.general` 当前纯文本，`⌥⌘T` / 菜单栏均可触发。
- 面板打开时可自动翻译最新记录：默认关闭；`AutoTranslationPolicy.latestItem` 按 `createdAt` 选出真正的最新记录（固定条目只在列表排序中靠前，不会冒充最新），再检查签名、可翻译类型、检测语言与目标语言；每条记录只自动触发一次，图片与同语言文本跳过。旧版本默认开启，升级时做一次性关闭迁移，之后尊重用户选择。
- Google / Bing 使用非官方 HTTP 接口；DeepL 非官方为实验性 JSON-RPC 通道。官方适配使用各家标准 HTTPS API。
- API 凭证保存在 Keychain；导出备份、日志与 UserDefaults 不包含密钥。

### 6.10 图片文字识别

- 图片预览底部「提取文字」、右键菜单或 `⌘R` 打开 OCR 面板；`⌘T` 在图片上也会进入识图。
- `OCRService` 在后台任务中调用 Vision：先用 `CGImageSource` 生成最长边 4096px、已应用方向变换的缩略图，再执行 `.accurate` 的 `VNRecognizeTextRequest`，并开启语言纠正。
- 识别语言可在设置中选择自动检测、中文（简体 / 繁体）、英语或日语；指定语言时会过滤 Vision 支持的语言代码。
- 识别结果按视觉位置从上到下、从左到右排序，合并为换行文本；可在 TextEditor 中修改。
- 识别文字按「内容哈希 + 识别语言」缓存在 `OCR/` 目录，编辑后同步更新；默认不进入备份，可在设置 → 智能中清除。
- 多选 2 张以上图片时，`MultiSelectionBar` 显示「识别文字」；`OCRService.presentBatch` 按顺序逐张识别，逐张结果支持编辑（切换到单张面板）、复制、翻译，底部可复制全部或保存为合并片段。
- 点击「翻译」调用 `TranslationService.present(text:title:)`，复用当前目标语言、引擎顺序、授权与翻译缓存。
- OCR 全程本地执行，图片不会离开设备。

### 6.11 顶部剪贴板挂架

- 挂架位置由 `ClipboardShelfEdge` 决定：顶部 / 左侧 / 右侧三选一，可在设置中切换。
- `ClipboardShelfController` 在收起时以 10Hz、展开时以 30Hz 轮询 `NSEvent.mouseLocation`；顶部模式取菜单栏中间三分之一，侧边模式取屏幕可见区域左 / 右边缘中间三分之一。悬停 0.25 秒后展开，离开挂架 0.5 秒后收起。
- 挂架是透明 `NSPanel`：顶部模式覆盖屏幕宽度、高度 260pt；侧边模式宽 232pt、高度等于可见屏幕高度。使用 `.nonactivatingPanel`，不激活应用、不抢当前应用的键盘焦点；`ShelfHostingView` 重写 `acceptsFirstMouse`，首次点击即落到卡片上。
- 展开 / 收起：整个挂架窗口从对应屏幕边缘外滑入，顶部从菜单栏上方整体下滑，左侧 / 右侧从屏幕左 / 右边缘水平滑入；展开 0.8 秒、收起 0.6 秒，使用缓入缓出曲线。`ClipboardShelfPanel` 重写 `constrainFrameRect`，否则 AppKit 会把屏幕外的起始位置夹回屏幕内，顶部就会直接跳到终点。
- 顶部模式使用水平绳线；侧边模式使用贴近屏幕边缘的竖向导轨和短臂，卡片通过外侧顶角的夹子挂在短臂上；超出屏幕的卡片通过滚动查看。
- 面板默认 `ignoresMouseEvents = true`；SwiftUI 通过 `PreferenceKey` 上报卡片与筛选栏的命中矩形，控制器按 30Hz 把鼠标位置换算到面板顶部坐标并切换点击穿透。面板空白区域不拦截下方应用。
- 加载数量来自设置（6 / 8 / 10 / 12 / 不限），是加载上限而不是屏幕可见上限；顶部卡片横向排列，侧边卡片纵向排列。加载内容超出视口时，只渲染可见范围附近的卡片，并在顶部横向 / 侧边纵向滚动。
- 卡片高度由内容决定：图片按 `imageDimensions` 的真实宽高比计算，文本 / 代码 / 链接使用展示片段的行数估算；顶部与侧边分别有最大高度，超出时在卡片内截断。侧边卡片间距加大到 20pt，为回形夹线环和卡片夹口留出空间。
- 滚动位置保存在 `ShelfInteractionState.scrollOffset`，视图上报最大滚动距离；控制器在 `ShelfHostingView.scrollWheel(with:)` 中接管滚轮事件并夹紧边界。顶部同时支持横向滑动与鼠标滚轮，侧边使用纵向滑动。
- 滚动时挂架保持固定：顶部绳子不动，卡片沿绳滑动；侧边竖轨固定在屏幕边缘，每张卡片通过一条短臂连到夹子线环，卡片挂在短臂内侧。滚动指示器只在滚动后短暂显示，避免与挂架线条混淆。
- 卡片点击调用 `ClipboardManager.copyToPasteboard`，同步 `changeCount`，不会生成新历史；复制成功后挂架根据 `settings.shelfCopyBehavior` 保持展开、立即收起或延迟 0.6 秒收起，并显示短暂「已复制」反馈。应用内生成的文本（识图、翻译、片段、Markdown / 颜色格式等）通过 `copyTextToPasteboard` 写入粘贴板后，会用 `handleCapture` 同步进入历史并按内容哈希去重。`copyPlainTextToPasteboard` 只写纯文本、不生成历史，供「复制为纯文本」和「富文本只复制纯文本」使用。
- 悬停状态由控制器根据同一套命中矩形计算并写入 `ShelfInteractionState`，不依赖 SwiftUI `onHover`，因此卡片之间的点击穿透切换不会留下错位或卡住的高亮。
- 悬停卡片底部显示操作条：预览、提取文字、翻译、置顶、删除；图片卡片先进入 OCR 窗口，识别完成后再点击翻译。
- 筛选栏使用点击手势而非 `Button`，并把材质背景与描边设为不参与命中测试；这是非激活面板中稳定响应点击的关键。
- 卡片通过 `ItemDragProvider` 支持拖拽到其他应用；右键菜单提供预览、复制、置顶 / 取消置顶、复制纯文本、打开链接 / 文件、Finder 定位、保存图片、复制 Markdown 与颜色格式；悬停底部显示预览 / 提取文字 / 翻译 / 置顶操作。
- 卡片按条目 ID 复用视图：删除或过滤后新出现的卡片会得到新的夹子状态；`ShelfClipView` 还会在 `itemID` 变化时重置释放状态，避免新卡片继承已打开夹子而无法再次删除。
- `ShelfCardView` 的外框必须使用传入的 `cardHeight`，不能使用固定高度；固定高度会让短卡片的内容被上移、长卡片的内容被下移，导致夹子离线并压住下一张卡片。
- 顶部绳线的下垂弧度加大，卡片不设置基础旋转，夹子线环中心直接落在绳线上；侧边短臂的高度取卡片顶部加夹子线环中心，因此夹子始终对准短臂。卡片内容严格按动态卡片高度布局，长卡片不会溢出到下一张；筛选栏上方再叠加渐隐遮罩，避免遮挡筛选栏。
- 夹子本身是删除入口：金色回形夹的线环穿过绳线 / 短臂，卡片上沿进入夹口，点击后夹子先抬起打开，约 0.2 秒后 `ShelfCardView` 的 `isFalling` 状态以独立的 ease-in 动画旋转、横向漂移并下落 150pt；卡片下落时长由 `settings.shelfCardFallDuration` 控制（默认 0.75 秒）。夹子和卡片已分离：下落变换只作用于卡片主体，夹子先留在线上，约半程后再用独立的 `isClipDropping` 状态旋转下落并淡出。两者都结束后才删除条目，剩余卡片再用列表弹簧补位。此前把下落挂在列表的 removal transition 上，会被容器的 `.animation(value: ids)` 覆盖成约 0.2 秒，因此现在改为卡片内部状态动画。
- 主面板打开时调用 `NSApp.activate(ignoringOtherApps: true)`，行内操作按钮、复制行、分类药丸等 SwiftUI 控件使用 `pointingHandCursor()` 推入 `NSCursor.pointingHand`；挂架是非激活面板，系统不会显示非激活窗口的光标变化，因此 `ClipboardShelfController` 在指针进入夹子 / 操作条 / 筛选栏的精确命中目标时短暂激活 HaoPaste 并推入光标，面板收起后恢复进入前的应用。卡片主体仍保持非激活悬停，避免仅移动鼠标就抢焦点。
- 卡片命中区域在悬停抬升时向四周扩大，尤其覆盖夹子线环，保证夹子可点击。
- 预览 / 识图 / 翻译都以独立浮动卡片出现在当前屏幕中央；`ShelfPreviewPanelController` 复用 `PreviewOverlayView`，`ShelfOCRPanelController` 复用 `OCRPaneView`，翻译复用快捷翻译卡片。弹框窗口尺寸与卡片一致并启用 `hasShadow = true`，使用 macOS 原生窗口阴影；SwiftUI 阴影只在主面板内嵌遮罩场景保留。挂架在这些卡片打开期间暂停自动收起，关闭后恢复。
- 控制器在挂架收起时使用 10Hz 轮询，展开时切到 30Hz；定时器带 20% tolerance，降低空闲唤醒与能耗。
- 筛选切换时，卡片使用插入 / 移除过渡，横杆的起点、终点与下垂幅度通过 `Animatable` 平滑伸缩；侧边导轨同样支持端点动画。挂架容器除了监听数量，还监听 `loadedItems.map(\.id)`：达到加载上限时数量不变但卡片身份会替换，仅靠数量无法触发新卡片动效。
- 展开前会检查：HaoPaste 是否位于前台、是否有全屏窗口覆盖当前屏幕、用户是否刚点过菜单栏。点击菜单栏会隐藏挂架并把本次悬停标记为抑制，直到鼠标离开菜单栏。
- 活动空间 / 屏幕参数变化时自动收起；支持「减弱动态效果」，此时使用无动画的展开 / 收起。

### 6.12 键盘事件

`PanelController` 使用 `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` 在面板为 key window 时处理：

- 方向键：更新 `PanelViewState.selectedID`；按住 `⇧` 时扩展多选范围；
- `⌘⇧A`：全选当前可见结果；
- 回车：复制选中项；多选时合并复制并关闭；
- `⌘P` / `⌘Y` / `⌘T` / `⌘R` / `⌘⌫` / `⌘W` / `⌘1–9`；全局 `⌥⌘T` 由独立的 Carbon hotkey 打开快捷翻译卡片。
- `esc`：取消多选；清空搜索；预览中关闭预览；翻译中关闭翻译；识图中关闭识图；否则关闭面板。
- 预览打开时，方向键切换预览条目，回车 / `⌘C` 复制并关闭，其他命令快捷键被忽略。

其余按键原样交还 AppKit / 输入法，因此搜索框和中文输入法保持正常工作。

全局呼出快捷键由 `AppSettings` 持有，默认 `⌥⌘V`。设置窗口中的 `ShortcutRecorderView` 用本地 key monitor 捕获新组合，要求至少包含 ⌘ / ⌥ / ⌃；`AppDelegate` 解绑旧 Carbon hotkey 后注册新组合，失败会恢复上一个可用配置并在设置页显示错误。

## 7. 界面设计规范

| Token | 值 |
| --- | --- |
| 面板圆角 | 16pt，`.continuous` |
| 卡片 / 图标圆角 | 10pt / 9pt，`.continuous` |
| 面板材质 | `.regularMaterial` |
| 窗口阴影 | 使用 macOS 原生窗口阴影，窗口尺寸与面板一致（720×560） |
| 描边 | 0.5pt，`Color.primary.opacity(0.08)` |
| 主色 | `Color.accentColor` |
| 字体 | SF Pro Rounded：`.system(..., design: .rounded)` |
| 图标 | SF Symbols + `.symbolRenderingMode(.hierarchical)` |
| 主要动效 | `.spring(response: 0.25, dampingFraction: 0.8)` |
| 列表动效 | `.spring(response: 0.32, dampingFraction: 0.86)` |
| 窗口动画 | 180ms 自定义三次贝塞尔 + 透明度 |
| 无障碍 | 跟随系统浅色 / 深色 / 强调色；`accessibilityReduceMotion` 下关闭弹簧和位移动画 |

面板整体为无标题栏 `NSPanel`，使用透明背景和原生窗口阴影，窗口尺寸与卡片一致，不再保留外层留白。卡片含悬停底色、选中强调色、1pt 上浮和轻微阴影。

## 8. 并发与性能

- 所有可变 UI 与业务状态（包括 `AppSettings`）都在 `@MainActor` 上；没有跨线程访问 SwiftUI 状态。
- 轮询使用 `Task.sleep(350ms)`，并持有 `ProcessInfo` 活动令牌以避免 App Nap 降低监听及时性。
- 历史写盘防抖 400ms，避免快速复制导致频繁 I/O。
- 列表使用 `LazyVStack`，仅渲染视口附近卡片。
- 图片列表只加载 560px 缩略图，原图只在复制或预览时读取。
- 富文本预览按需读取缓存 JSON；拖拽 Provider 也延迟到拖拽开始时构建，不增加列表渲染开销。
- 合并复制只遍历当前选中的条目；文件 URL 按路径去重，复杂度与选择数量线性相关。
- 翻译网络请求通过 `URLSession` 异步执行，不阻塞主线程；长文本按 Provider 上限分块，避免单次请求过大。
- OCR 在 `Task.detached` 中执行 Vision，主线程只负责状态与文本绑定；识别前生成 4096px 缩略图控制内存与耗时。
- 批量识图按顺序执行，避免同时解码多张大图；结果实时写回缓存，重复打开同一图片直接命中缓存。
- 去重哈希在采集线程（主线程）执行；对常规文本 / 图片足够快，超大内容可后续迁移到后台任务。
- 搜索在当前 200 条规模内同步执行；只对含 CJK 的内容按需做拼音转换，结果按相关性排序，无持久化索引。
- 当前默认上限为 200 条未置顶 + 任意置顶项，可在设置中调整为 100 / 200 / 500 / 1000；排序与搜索为 O(n log n) 级别，规模可控。

## 9. 隐私与安全

- 无账号、无遥测；默认不发起网络请求。在线翻译只有用户点击并授权后才发送当前文本，图片与历史不会上传。
- 翻译 API Key 保存在 Keychain；不写入 UserDefaults、日志或导出备份。
- OCR 使用本地 Vision，不上传图片；识别文字缓存在本机 `OCR/` 目录，默认不进入备份，可在设置中一键清除。
- Google / Bing / DeepL 非官方通道不受服务端 SLA 保障，可能违反服务条款；默认不自动启用 DeepL 非官方通道，并在设置中明确提示风险。
- 历史与图片保存在用户 Application Support 目录；翻译 API 凭证保存在 macOS 钥匙串，不写入备份或日志。
- 核心功能不申请辅助功能、屏幕录制、自动化权限；全局快捷键使用 Carbon。可选的划词翻译需要 Accessibility，仅在启用时读取当前选区。
- 隐藏类型过滤遵循 NSPasteboard 社区约定，但属于尽力而为：
  - 密码管理器若不设置隐藏类型，内容仍可能被记录；
  - 用户可在菜单栏随时暂停监听或清空未置顶记录。
- 隐私设置支持按应用排除：来源应用会在读取剪贴板内容之前被检查，排除应用的复制内容不会进入历史。
- 可关闭图片记录：新图片不会被保存或生成缓存；已有图片保持不动。
- App Sandbox 未启用（没有 entitlements），以便本地通用剪贴板与全局快捷键完整工作；因此不计划提交 Mac App Store。若未来上架，需要重新评估沙盒和分发策略。
- 分发构建使用 ad-hoc 签名；对外分发必须替换为 Developer ID 签名与公证。

### 划词翻译

- `SelectionTranslationController` 在设置开启且获得 Accessibility 权限后，安装被动全局鼠标/键盘监听。
- 鼠标抬起后延迟约 180ms，通过 `AXSelectedText` 读取前台应用选区，不模拟 `⌘C`。
- 全屏应用、安全输入、排除应用和 HaoPaste 自身会被过滤。
- 翻译图标为不抢焦点的非激活 `NSPanel`；点击后才创建紧凑翻译卡片。
- 卡片根据选区鼠标锚点放在附近，优先下方/右侧，空间不足时翻转。
- 当前版本只支持鼠标划词；键盘选择与完整翻译面板入口待后续版本。

### 本地化

- 源代码中的中文同时作为本地化 key，`Localization.swift` 的 `L()` 负责查表与格式化。
- 资源为 `en.lproj` 与 `zh-Hans.lproj`，工程 development language 为 `en`；默认按 `Locale.preferredLanguages` 选择（中文语言使用简体中文，其余语言使用英文），也可在设置中显式选择简体中文或英文。
- 语言设置保存在 `settings.appLanguage`，切换后通过重启应用生效；`AppLanguage.launchPreference` 固定当前进程使用的语言。
- 动态计数使用 `.stringsdict` 处理英文单复数；日期与相对时间使用 `AppLanguage.locale`，避免界面英文但日期仍跟随系统语言。

## 10. 测试与验证现状

### 自动化测试

124 个 XCTest 由 app target 作为测试宿主运行：

- 内容分类器边界：URL、HEX、JSON、代码、SQL、普通文本。
- `HotKeyConfiguration`：校验、修饰符转换、显示顺序。
- `ClipboardItem`：徽章、搜索、分类过滤。
- `AppSettings`：默认值、持久化、排除规则匹配、非法上限回退。
- `ClipboardStore`：文本 / 图片资产读写、缺失资产过滤。
- `ClipboardManager`：FIFO 裁剪、置顶保护、清空。
- 挂架：筛选规则、卡片宽度、动态高度、滚动上限与可见范围、顶部 / 侧边支架几何、菜单栏 / 侧边展开区域、面板位置、点击命中目标、文本类判断、位置 / 加载数量持久化。
- `HistoryArchiveService`：导出、导入、重复导入去重、无效归档报错。
- `SearchMatcher`：中文、拼音全拼 / 首字母、模糊匹配、相关性排序。
- `SnippetManager`：片段 CRUD、持久化、搜索、合并。
- 文件条目：展示、分类过滤、多文件哈希、文件 URL 复制。
- `HexColor` 解析与 RGB / HSL 输出；动作文本复制。
- 拼音 / 模糊搜索命中与相关性排序。
- Snippets CRUD、持久化、过滤、面板选中与备份合并。
- 富文本 RTF/HTML 缓存、回写与备份迁移。
- 预览状态生命周期、超长文本截断、富文本格式保留与颜色归一化。
- 文本 / 富文本 / 图片拖拽 Provider 的类型与数据内容；多文件拖拽 item 数量。
- 多选状态：⌘ 切换、⇧ 范围、锚点稳定、全选与删除后的裁剪。
- 合并复制：文本顺序、文件 URL、混合路径、去重、图片限制与剪贴板写入。
- 翻译 Provider：Google / Bing / DeepL / Azure / 百度 / Google Cloud 的请求参数、签名与响应解析。
- 翻译服务：多引擎回退、授权、长文本分块、内存缓存、同语言方向切换与未配置官方引擎跳过。
- 翻译设置：目标语言、启用状态、引擎顺序、授权与快捷翻译快捷键持久化。
- 快捷翻译：自动翻译策略、剪贴板文本读取、翻译快捷键默认值。
- OCR：成功 / 空结果 / 失败状态、编辑后缓存复用、批量识别与缓存复用、识别语言持久化，以及真实 Vision 中英文图片识别。

运行：`make test`。CI：`.github/workflows/ci.yml`，执行测试并构建 Release。

测试宿主会检测 XCTest 环境并跳过菜单栏、剪贴板轮询和全局快捷键注册，避免污染真实使用状态。

### 手工验证

- 面板在实际窗口服务器中可见、失焦可收起；
- 设置窗口四个标签页的离屏渲染；
- 自定义快捷键持久化与显示；
- 按应用排除与图片记录开关的实际行为；
- 备份导出 → 导入 → 再次导入去重；
- 浅色 / 深色 / 减弱动态效果渲染。

### 尚未自动化

- 全局快捷键的真实按键 UI 自动化（当前环境无法授予发送系统按键权限）；
- 登录项注册在签名 / 未签名构建上的完整系统授权流程；
- 面板 hover / 键盘导航 / 弹层的 UI smoke test；
- 超长文本 / 超大图片压力测试；
- 各应用剪贴板格式矩阵；
- 多显示器 / 多 Space / 全屏应用切换；
- 长期运行的内存与能耗。

## 11. 可扩展点

- **片段增强**：变量（日期 / 剪贴板内容）、分组、快捷键绑定。

- **设置层**：继续扩展外观、隐私、按应用排除等设置页。
- **快捷键抽象**：已迁移为可配置组合；后续可加入按键布局感知的显示名称。
- **数据层迁移**：当前 JSON 足够轻量；规模增长后可迁移 SQLite / SwiftData，保持 Repository 接口。
- **动作系统**：在复制之外增加打开链接、粘贴为纯文本、保存图片、运行快捷指令等动作。
- **格式扩展**：借助 `NSPasteboard.PasteboardType` 支持 RTF、HTML、文件 URL、多选。
- **自动粘贴**：需要在用户明确授权下使用 Accessibility API。
- **备份加密**：对导出的 zip 增加口令加密，保护本地剪贴板历史。
