# HaoPaste

一款原生、轻快、键盘优先的 macOS 剪切板管理器。用 `⌥⌘V` 从任何应用呼出无标题栏悬浮面板，搜索、选择、复制，一气呵成。

> 设计目标：接近 Raycast / Paste 的精致感，同时保持 Apple Human Interface Guidelines 的原生语义与克制。

| 浅色 | 深色 |
| --- | --- |
| ![浅色界面](Docs/screenshot-light.png) | ![深色界面](Docs/screenshot-dark.png) |

*界面预览使用示例数据，由应用内置的离屏渲染工具生成。*

---

## 功能

- **系统级唤起**：`⌥⌘V` 全局快捷键，或点击菜单栏剪贴板图标。
- **无标题栏悬浮面板**：`.regularMaterial` 磨砂背景、16pt 连续圆角、0.5pt 细描边、柔和阴影。
- **即时搜索**：按内容、来源应用、类型或格式搜索。
- **分类药丸**：全部 / 文本 / 代码 / 图片 / 链接，胶囊选中态平滑滑动。
- **键盘优先**：

  | 快捷键 | 行为 |
  | --- | --- |
  | `↑` `↓` | 切换选中条目 |
  | `↵` | 复制选中条目并关闭面板 |
  | `⌘1` – `⌘9` | 直接复制对应序号的条目 |
  | `⌘P` | 置顶 / 取消置顶 |
  | `⌘⌫` | 删除选中条目 |
  | `esc` | 有搜索词时清除搜索，否则关闭面板 |

- **卡片交互**：悬停高亮、1pt 微位移、弹簧动效；悬停后显示置顶与删除按钮；支持右键菜单。
- **智能识别**：自动区分纯文本、链接、代码 / JSON、颜色值（HEX）与图片。
- **来源应用**：记录复制内容时最前方的应用名称。
- **图片缩略图**：原图与缩略图分文件缓存，列表只加载缩略图。
- **安全过滤**：忽略 `org.nspasteboard.ConcealedType`、临时类型、自动生成类型以及常见密码管理器的私有类型。
- **去重**：相同内容不会产生重复记录，而是刷新时间并回到顶部；置顶状态保留。
- **历史限制**：未置顶记录最多 200 条，FIFO 自动淘汰；置顶记录永不自动清理。
- **原生适配**：跟随系统浅色 / 深色外观与强调色，尊重“减弱动态效果”，全部图标使用 SF Symbols 分层渲染。

点击条目只执行「复制」，不会自动粘贴到上一个应用，因此应用不需要辅助功能（Accessibility）权限。

## 快速开始

环境要求：macOS 14+、Xcode 15+（本工程使用 Xcode 26.5 构建验证）。

```bash
# 直接构建并运行
make run

# 仅构建
make build

# 用可复现的示例数据启动，便于查看界面
make demo
```

也可以直接打开 `HaoPaste.xcodeproj` 运行。工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成；新增源文件后运行 `make project` 或 `xcodegen generate` 重新生成工程。

首次启动后，应用会驻留在菜单栏。按 `⌥⌘V` 呼出面板。

## 快捷键与交互细节

- 在搜索框中输入会即时过滤；`esc` 第一次清空搜索，第二次关闭面板。
- 面板失焦时自动关闭，并把焦点还给之前的应用。
- 鼠标悬停在条目上显示置顶 / 删除按钮；点击条目主体复制。
- 被选中条目使用系统强调色底色与边框，键盘与鼠标操作共享同一套选中状态。
- `⌘1`–`⌘9` 对应当前过滤结果中的前九条。

## 数据结构与持久化

使用轻量 JSON 存储，无第三方依赖：

```text
~/Library/Application Support/HaoPaste/
├── history.json          # [ClipboardItem]
└── Images/
    ├── <UUID>.png        # 原图
    └── <UUID>-thumb.png  # 列表缩略图
```

开发与测试可以通过环境变量覆盖存储位置：

```bash
HAOPASTE_STORAGE_DIR=/tmp/haopaste-dev ./HaoPaste.app/Contents/MacOS/HaoPaste
```

核心模型：

```swift
struct ClipboardItem {
    let id: UUID
    var type: ClipboardItemType         // .text / .image / .colorHex / .url / .code
    var content: String                 // 文本内容，或图片文件名
    var plainText: String               // 搜索与纯文本输出
    var isPinned: Bool
    var createdAt: Date
    var sourceApp: SourceApplication?   // bundle ID + 名称
    var contentHash: String             // SHA-256 去重指纹
    var imageFileName: String?
    var thumbnailFileName: String?
    var imageDimensions: ImageDimensions?
}
```

## 架构

```text
HaoPaste/
├── App/
│   ├── HaoPasteApplication.swift    # AppKit 入口，菜单栏驻留应用
│   ├── AppDelegate.swift            # 依赖装配、主菜单、调试入口
│   ├── PanelController.swift        # NSPanel、定位、键盘事件、焦点恢复
│   ├── GlobalHotKey.swift           # Carbon 全局快捷键（⌥⌘V）
│   └── StatusBarController.swift    # 菜单栏图标与右键菜单
├── Services/
│   ├── ClipboardMonitor.swift       # changeCount 轮询、隐藏类型过滤
│   ├── ClipboardManager.swift       # 去重、置顶、FIFO、复制、可观察状态
│   ├── ClipboardStore.swift         # JSON 持久化与图片资产
│   ├── ContentClassifier.swift      # 文本 / URL / JSON / 代码 / HEX 识别
│   ├── ContentHasher.swift          # SHA-256 指纹
│   └── ImageProcessor.swift         # PNG 归一化与缩略图生成
├── Models/ClipboardItem.swift
├── State/PanelViewState.swift       # 搜索、筛选、选中项与焦点
├── Views/                           # ContentView、ItemRowView 及组件
├── Theme/Theme.swift                # 圆角、间距、弹簧动效、细描边
└── Support/                         # DEMO 数据与离屏截图工具（仅 Debug）
```

### 监听流程

1. 每 350ms 比较一次 `NSPasteboard.general.changeCount`。
2. 检测到变化后，先过滤隐藏 / 临时 / 密码管理器类型。
3. 依次尝试图片、纯文本；对文本做类型识别与 SHA-256 指纹。
4. 与历史指纹比较：命中则更新时间并移到顶部，否则创建新记录。
5. 图片写入磁盘并生成缩略图；记录写入 JSON（400ms 防抖）。
6. 重算并裁剪未置顶历史至 200 条。

### 复制流程

应用自身写入剪贴板后立即同步 `changeCount`，避免把「再次复制历史条目」误采集为一条新记录。同时刷新该条目的使用时间，使下次打开面板时位于更靠前的位置。

## 开发

```bash
make project   # 重新生成 Xcode 工程
make build     # Debug 构建到 .build/
make run       # 构建并打开
make demo      # 使用 /tmp/haopaste-demo 的示例数据启动
make clean
```

Debug 构建内置两个仅用于视觉验收的参数：

```bash
# 离屏渲染面板截图（需要先通过 Launch Services 启动）
open -n .build/Build/Products/Debug/HaoPaste.app --args --render /tmp/panel.png

# 深色外观渲染
launchctl setenv HAOPASTE_RENDER_APPEARANCE dark
open -n .build/Build/Products/Debug/HaoPaste.app --args --render /tmp/panel-dark.png
launchctl unsetenv HAOPASTE_RENDER_APPEARANCE
```

`make demo` 等价于以 `--demo --show` 启动一个带有临时存储目录的 Debug 实例。

## 已知边界 / Roadmap

- 目前仅支持文本、链接、代码 / JSON、HEX 颜色和图片；文件、富文本、多图列表尚未纳入。
- 快捷键固定为 `⌥⌘V`，尚未提供设置窗口与自定义快捷键。
- 点击条目只复制，不自动粘贴（不申请辅助功能权限）。
- 未实现开机启动、iCloud 同步、按应用排除规则。
- 应用为本地 ad-hoc 签名；分发前需配置自己的 Team、Hardened Runtime 与公证流程。
- 打包资源、图标、菜单栏图标均为 SF Symbols 体系；应用图标由 `Scripts/generate-app-icon.swift` 生成，可重复构建。
