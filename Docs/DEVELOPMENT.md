# 开发与发布指南

## 1. 环境要求

| 项目 | 版本 |
| --- | --- |
| macOS | 14+（开发验证环境为 macOS 26.5） |
| Xcode | 15+（开发验证环境为 Xcode 26.5） |
| XcodeGen | 可选；工程文件已提交，只有新增/移动源文件后需要重新生成 |
| 网络 | 构建与运行均不需要；无第三方运行时依赖 |

安装 XcodeGen：

```bash
brew install xcodegen
```

## 2. 获取工程与运行

### Xcode

```bash
open HaoPaste.xcodeproj
```

选择 `HaoPaste` scheme，`Run` 即可。应用为菜单栏驻留应用，启动后不会出现 Dock 图标；按 `⌥⌘V` 或点击菜单栏图标打开面板。

### 命令行

```bash
make run       # Debug 构建 + open
make demo      # 使用 /tmp/haopaste-demo 和示例数据启动
make build     # 仅 Debug 构建
make release   # Release 构建（用于日常使用）
```

Debug 构建输出：

```text
.build/Build/Products/Debug/HaoPaste.app
```

Release 构建输出：

```text
.build/release/Build/Products/Release/HaoPaste.app
```

### 调试用启动参数

| 参数 / 环境变量 | 用途 |
| --- | --- |
| `--show` | 启动后直接显示面板 |
| `--demo` | Debug 构建注入 11 条示例数据（空历史时） |
| `--storage <path>` | 指定历史 / 图片存储目录 |
| `HAOPASTE_STORAGE_DIR=<path>` | 环境变量形式的存储覆盖 |
| `--render <path>` | Debug：离屏渲染面板 PNG 后退出 |
| `--render-settings <path>` | Debug：离屏渲染设置窗口 PNG 后退出 |
| `HAOPASTE_RENDER_APPEARANCE=dark` | Debug 离屏渲染时使用深色外观 |
| `HAOPASTE_RENDER_SETTINGS_TAB=general\|history\|snippets\|intelligence\|privacy\|about` | Debug 设置渲染的标签页 |
| `HAOPASTE_RENDER_PREVIEW=image\|text` | Debug 渲染预览界面（图片或富文本） |
| `HAOPASTE_RENDER_MULTI=<数量>` | Debug 渲染多选界面并选中前 N 条 |
| `HAOPASTE_RENDER_TRANSLATION=success\|consent\|error` | Debug 渲染翻译面板状态 |
| `HAOPASTE_RENDER_OCR=success\|empty\|batch` | Debug 渲染单张 / 批量识图状态 |
| `--render-quick <path>` | Debug 渲染快捷翻译卡片 |
| `--show-quick` | Debug：启动后用示例剪贴板文本显示快捷翻译卡片 |
| `--render-shelf <path>` | Debug：离屏渲染剪贴板挂架 PNG 后退出 |
| `HAOPASTE_RENDER_SHELF_EDGE=left\|right` | Debug：渲染左侧 / 右侧挂架（默认顶部） |
| `HAOPASTE_RENDER_SHELF_HOVER=1` | Debug：渲染第一张卡片的悬停操作条 |
| `--show-shelf` | Debug：启动后用示例数据展开剪贴板挂架 |
| `--show-settings` | Debug：启动后直接打开设置窗口 |
| `--export-history <path>` | Debug：将指定 storage 的历史导出为 zip 后退出 |
| `--import-history <path>` | Debug：将 zip 合并导入指定 storage 后退出 |

示例：

```bash
make demo

open -n .build/Build/Products/Debug/HaoPaste.app \
  --args --demo --show --storage /tmp/haopaste-demo
```

> `HaoPaste.app/Contents/MacOS/HaoPaste` 直接执行时，macOS 可能不会按 Launch Services 的常规流程激活窗口。需要展示 UI 时请使用 `open -n HaoPaste.app --args ...`。

## 3. 工程结构

```text
HaoPaste/
├── App/           # 入口、Delegate、NSPanel、状态栏、全局快捷键
├── Models/        # 持久化模型
├── Services/      # 监听、管理、存储、分类、哈希、图片
├── State/         # 面板 UI 状态
├── Views/         # SwiftUI 界面（面板 + Shelf + Settings）
├── Theme/         # 设计 token
├── Resources/     # Assets.xcassets / AppIcon
├── Support/       # DEBUG：示例数据、离屏渲染
└── Utilities/     # 相对时间

Scripts/
├── generate-app-icon.swift
├── package-dmg.sh
└── install-app.sh

HaoPasteTests/        # XCTest：分类、设置、存储、片段、管理器、备份
.github/workflows/    # CI：测试 + Release 构建

Docs/
├── README.md
├── USER_GUIDE.md
├── ARCHITECTURE.md
├── DEVELOPMENT.md
└── ROADMAP.md
```

工程由 `project.yml` 通过 XcodeGen 生成。**新增 `.swift` 文件后请运行**：

```bash
make project
```

## 4. 发布与安装

### 4.1 构建 Release

```bash
make release
```

### 4.2 生成 DMG

```bash
make dmg
```

输出：

```text
dist/HaoPaste-0.13.19.dmg                 # 安装包（app + Applications 快捷方式）
dist/HaoPaste-0.13.19.dmg.sha256          # SHA-256 校验
```

> `dist/` 只保留 DMG，不再额外放一份 `.app`，避免 Spotlight / Launch Services 中出现多个 HaoPaste 副本。可运行的 Release 产物位于 `.build/release/Build/Products/Release/HaoPaste.app`。

DMG 中包含 `安装说明.txt`，用户拖入 Applications 即可。应用本身是自包含的，不需要 Xcode、命令行或额外运行时。

### 4.3 安装到本机

```bash
make install
```

脚本逻辑：

1. 如果 `/Applications` 可写，安装到 `/Applications/HaoPaste.app`；
2. 否则安装到 `~/Applications/HaoPaste.app`；
3. 给 app 移除 quarantine 属性并做 ad-hoc 签名校验；
4. 通过 Launch Services 启动应用。

也可以手动安装：

```bash
ditto .build/release/Build/Products/Release/HaoPaste.app /Applications/HaoPaste.app
open /Applications/HaoPaste.app
```

### 4.4 签名、公证与对外分发

当前本地构建使用 **ad-hoc 签名**。在自己的 Mac 上可以直接打开；如果把 DMG 发给其他用户，Gatekeeper 可能提示无法验证开发者。

正式分发前：

1. 在 Xcode 的 Signing & Capabilities 中配置 Developer ID Application 证书；
2. 确保 `ENABLE_HARDENED_RUNTIME = YES`（工程已开启）；
3. 使用 Developer ID 重新签名：

```bash
codesign --force --deep --options runtime --timestamp \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  ".build/release/Build/Products/Release/HaoPaste.app"
```

4. 签名后重新生成 DMG（打包脚本会保留有效签名）；
5. 提交 Apple Notary Service 并 stapling：

```bash
xcrun notarytool submit "dist/HaoPaste-0.13.19.dmg" \
  --keychain-profile "haopaste-notary" --wait

xcrun stapler staple "dist/HaoPaste-0.13.19.dmg"
xcrun stapler validate "dist/HaoPaste-0.13.19.dmg"
```

也可以对 `.app` 先公证再打包（Apple 推荐流程根据分发方式调整）。需要 Apple Developer Program 账号。

## 5. 版本号与发布检查

版本号位于 `project.yml`：

```yaml
MARKETING_VERSION: "0.13.19"
CURRENT_PROJECT_VERSION: "42"
```

修改后运行 `make project` 再构建。发布前检查：

- [ ] `make test` 全部通过
- [ ] `make release` 无警告/错误（AppIntents 元数据提示可忽略）
- [ ] 全新用户目录（清空 App Support + UserDefaults）启动正常
- [ ] 首次启动自动展示面板；再次打开应用会显示面板
- [ ] 默认 / 自定义快捷键、`esc`、`↵`、`⌘1–9`、`⌘P`、`⌘⌫` 行为正确
- [ ] 快捷键冲突时设置窗口显示错误并恢复上一组可用快捷键
- [ ] 文本 / 链接 / 代码 / JSON / HEX / 图片采集正常
- [ ] 去重、置顶、删除、清空未置顶 / 全部正常
- [ ] 暂停监听后不再新增记录
- [ ] 历史上限切换生效，置顶记录不受影响
- [ ] 登录时自动启动可注册 / 注销；被系统要求批准时有提示
- [ ] 排除来源应用后新内容不入库；移除排除后恢复
- [ ] 文件 / 多选文件复制后出现在「文件」分类；文件删除后显示不可用
- [ ] 链接打开、图片保存、颜色 RGB / HSL 复制正常
- [ ] 拼音全拼 / 首字母和模糊搜索能命中中文与英文内容
- [ ] 片段可创建 / 编辑 / 删除，面板中可复制，备份导入后可恢复
- [ ] 富文本复制后保留 RTF/HTML；纯文本回退与备份恢复正常
- [ ] 关闭 / 开启图片记录后，相应类型按预期入库或忽略
- [ ] 设置窗口的通用 / 历史 / 片段 / 隐私 / 关于五个页面正常，窗口可关闭重开
- [ ] 历史导出后可以在空库中完整导入；重复导入不会产生重复项
- [ ] 备份中的图片 / 缩略图 / 置顶状态导入后保持可用；缺失图片会被跳过并计入提示
- [ ] 重启后历史、缩略图与设置恢复
- [ ] 浅色 / 深色 / 减弱动态效果表现正常
- [ ] DMG 可以拖入 Applications 并正常启动
- [ ] `codesign --verify --deep --strict` 通过
- [ ] 更新 `Docs/` 与 README 所需截图

## 6. 测试与诊断

### 自动化测试

```bash
make test
```

等价于：

```bash
xcodebuild \
  -project HaoPaste.xcodeproj \
  -scheme HaoPaste \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  test
```

当前 113 个测试覆盖：

- 内容分类器：URL / HEX / JSON / 代码 / SQL / 普通文本边界。
- `HotKeyConfiguration`：默认值、修饰符、显示顺序、校验。
- `ClipboardItem`：格式徽章、搜索、分类过滤。
- `AppSettings`：默认值、持久化、快捷键、隐私排除匹配、非法上限回退。
- `ClipboardStore`：文本 / 图片资产往返、缺失图片过滤。
- `ClipboardManager`：FIFO 裁剪、置顶保护、清空逻辑。
- `HistoryArchiveService`：导出 → 空库导入 → 重复导入去重、无效归档报错。
- 预览：状态生命周期、超长文本截断、富文本格式保留与颜色归一化。
- 拖拽：文本 / RTF / 图片 Provider 的类型注册与数据内容。
- 多选：⌘ 切换、⇧ 范围、锚点、全选与删除后的选择裁剪。
- 合并：文本顺序、文件 URL、混合路径、去重、图片限制与剪贴板写入。
- 翻译 Provider：Google / Bing / DeepL / Azure / 百度 / Google Cloud 的请求参数、签名与响应解析。
- 翻译服务：多引擎回退、授权、长文本分块、缓存、同语言方向切换与未配置引擎跳过。
- 翻译设置：目标语言、启用状态、引擎顺序、授权与快捷翻译快捷键持久化。
- 快捷翻译：自动翻译策略、剪贴板读取、翻译快捷键默认值。
- OCR：成功 / 空结果 / 失败状态、编辑后缓存复用、批量识别与缓存复用、识别语言持久化，以及真实 Vision 中英文图片识别。

测试宿主使用的是真实 app target，但 `AppDelegate` 会检测 XCTest 环境并跳过菜单栏、轮询和全局快捷键初始化。CI 工作流位于 `.github/workflows/ci.yml`，会运行测试并额外执行一次 Release 构建。

### 手动回归

```bash
make demo
```

多选回归：按住 `⌘` 点击两条文本 → 按 `↵`，确认剪贴板内容按可见顺序换行合并；选中图片时合并按钮应禁用并显示提示。

翻译回归：联网状态下选中一段英文 → `⌘T` → 允许在线授权，确认 Google 或 Bing 返回中文；在设置 → 智能中配置官方 Key 后点击「测试连接」；翻译长文本时确认进度与分段结果。CI 不访问真实翻译接口，Provider 测试全部使用 `URLProtocol` 模拟响应。

识图回归：复制一张带文字的截图 → `⌘R` 或图片预览「提取文字」→ 确认文字可编辑、复制、保存片段，并可直接进入翻译；没有文字的图片应显示「未识别到文字」。
批量识图回归：复制两张带文字的图片 → `⌘` 多选 → 底部「识别文字」→ 确认两张结果依次出现，可逐张编辑 / 复制 / 翻译，并可复制全部；重新打开同一批图片时应直接命中本地缓存。切换识别语言后再次识别，应使用新的语言配置。

快捷翻译回归：复制英文文本 → 在任意应用按 `⌥⌘T` → 确认翻译卡片出现并自动翻译，`↵` 复制译文后回到原应用；右键菜单栏图标选择「翻译剪贴板」；在设置 → 通用中修改快捷翻译快捷键；复制一条新的英文文本后打开面板，确认「打开面板时翻译最新记录」只自动触发一次。

除了示例数据，还可以用系统剪贴板快速验证：

```bash
printf 'hello from terminal' | pbcopy
open -n .build/Build/Products/Debug/HaoPaste.app --args --show
```

### 查看日志

```bash
log stream --style compact --predicate 'process == "HaoPaste"'
```

应用内的关键错误通过 `NSLog` 输出到系统日志，包括历史加载、图片写入和快捷键注册失败。

### 重置本地状态

```bash
pkill -x HaoPaste || true
rm -rf "$HOME/Library/Application Support/HaoPaste"
defaults delete com.hao.HaoPaste hasCompletedFirstLaunch 2>/dev/null || true
```

### 卸载

```bash
pkill -x HaoPaste || true
rm -rf /Applications/HaoPaste.app "$HOME/Applications/HaoPaste.app"
rm -rf "$HOME/Library/Application Support/HaoPaste"
defaults delete com.hao.HaoPaste 2>/dev/null || true
```

## 7. 已知开发注意事项

- **不要用 `swift run`**：本工程是 Xcode application target，不是 Swift Package。请用 Xcode 或 `open` 启动 `.app`。
- **修改 AppDelegate 的 first launch 行为**：调试时若不想自动弹面板，可先运行 `defaults delete com.hao.HaoPaste hasCompletedFirstLaunch`，或在 `--demo` 流程中验证。
- **设置项存储**：快捷键与历史上限保存在 `UserDefaults`（`com.hao.HaoPaste`），没有单独的 settings 文件。登录项状态以 `SMAppService.mainApp.status` 为准。
- **设置窗口调试**：`open -n .build/Build/Products/Debug/HaoPaste.app --args --show-settings`；或使用离屏渲染命令检查四个标签页。
- **文件调试**：复制 Finder 中的文件后检查该文件的虚线记录；测试会通过临时文件验证文件 URL 复制。
- **备份调试**：导出与导入使用 `/usr/bin/ditto` 生成 / 解包 zip，不依赖第三方库。
  ```bash
  open -n .build/Build/Products/Debug/HaoPaste.app --args \
    --storage /tmp/haopaste-source --export-history /tmp/haopaste-backup.zip
  open -n .build/Build/Products/Debug/HaoPaste.app --args \
    --storage /tmp/haopaste-target --import-history /tmp/haopaste-backup.zip
  ```
- **截图渲染**：`DebugRenderer` 使用真实的 `NSHostingView` + 窗口缓存，避免 `ImageRenderer` 对 TextField / LazyVStack 的渲染限制。不要删除这段 Debug 工具后继续使用 README 中的渲染命令。
- **DMG 未提交到 Git**：`dist/` 被 `.gitignore` 排除。每次发布请重新运行 `make dmg`。
- **应用图标**：修改 `Scripts/generate-app-icon.swift` 后重新生成 10 个尺寸，或直接替换 `AppIcon.appiconset` 中的 PNG。

## 8. Git 约定

- 主分支：`main`
- 提交信息建议使用 `feat: ...`、`fix: ...`、`docs: ...`、`chore: ...`
- 发布产物、DerivedData、用户数据和签名材料不提交
- 功能变更请同步更新 `Docs/` 中相关章节与 `ROADMAP.md` 状态


### GitHub Actions 发布

推送 `v*` tag 会触发 `.github/workflows/release.yml`：

1. 校验 tag 与 `project.yml` 的 `MARKETING_VERSION` 一致
2. 运行 XCTest
3. 构建 Release `.app` 和无 Finder 依赖的 DMG
4. 生成 Release 说明（上一 tag 到当前 tag 的提交）
5. 创建或更新 GitHub Release，并上传 DMG 与 SHA-256

发布步骤：

```bash
# 先修改 project.yml 的 MARKETING_VERSION / CURRENT_PROJECT_VERSION
xcodegen generate
git add .
git commit -m "release: vX.Y.Z"
git tag vX.Y.Z
git push origin main
git push origin vX.Y.Z
```

CI 使用 `HAOPASTE_DMG_LAYOUT=0` 跳过 Finder 窗口布局，改为在 DMG 中放入 `安装说明.txt`；本机 `make dmg` 仍会使用 Finder 背景和安装提示。
