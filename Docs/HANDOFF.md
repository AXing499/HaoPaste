# 开发与发布交接

本文档说明 HaoPaste 当前的构建、测试、自动发布、本地化和截图流程，并附一段可直接交给其他 AI 的交接提示词。

## 1. 项目概览

- 仓库：<https://github.com/AXing499/HaoPaste>
- 主分支：`main`
- 应用形态：macOS 14+ 菜单栏应用（`LSUIElement`），SwiftUI + AppKit，无第三方运行时依赖
- 工程生成：[XcodeGen](https://github.com/yonaskolb/XcodeGen)，入口为 `project.yml`
- 版本文件：`project.yml` 中的 `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION`
- Release 说明：`CHANGELOG.md`，必须包含与版本号一致的中英双语章节
- 签名：本地 ad-hoc 签名；不使用 Developer ID，不做公证
- 更新源：默认读取 GitHub Releases API
  `https://api.github.com/repos/AXing499/HaoPaste/releases/latest`

## 2. 本地开发命令

```bash
make project   # xcodegen generate
make build     # Debug 构建
make run       # Debug 构建并启动
make demo      # 使用可复现示例数据启动
make test      # 120 个 XCTest（默认英文测试环境）
make release   # Release 构建
make dmg       # 生成 dist/HaoPaste-<version>.dmg
make install   # 安装 Release 到 /Applications 或 ~/Applications
```

如需验证中文测试环境：

```bash
xcodebuild -project HaoPaste.xcodeproj -scheme HaoPaste \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath .build test -testLanguage zh-Hans
```

## 3. 自动发布是怎么实现的

自动发布由两个 GitHub Actions 工作流组成。

### 3.1 CI：`.github/workflows/ci.yml`

触发条件：

- push 到 `main`
- pull request

执行内容：

1. checkout
2. 运行 XCTest（`-testLanguage en`）
3. 构建 Release `.app`

CI 不创建 Release，也不上传 DMG。

### 3.2 Release：`.github/workflows/release.yml`

触发条件：

- 推送 `v*` tag，例如 `v0.14.2`

执行内容：

1. **Resolve version**：读取 tag 与 `project.yml` 的 `MARKETING_VERSION`，两者必须完全一致，否则失败
2. **Run unit tests**：运行 120 个 XCTest
3. **Build Release app**：生成 `.build/release/Build/Products/Release/HaoPaste.app`
4. **Build DMG**：设置 `HAOPASTE_DMG_LAYOUT=0`，调用 `Scripts/package-dmg.sh`，生成 DMG 与 SHA-256
5. **Read changelog**：从 `CHANGELOG.md` 提取 `## <version>` 到下一个 `##` 之间的内容；没有对应章节会直接失败
6. **Write release notes**：拼接标题、双语安装说明和 `CHANGELOG.md` 的双语变更说明
7. **Publish GitHub release**：
   - Release 不存在：`gh release create`
   - Release 已存在：`gh release edit` + `gh release upload --clobber`

发布资产：

- `HaoPaste-<version>.dmg`
- `HaoPaste-<version>.dmg.sha256`

工作流使用仓库自带的 `GITHUB_TOKEN`，权限为 `contents: write`，不需要额外 secret。

### 3.3 发布步骤

```bash
# 1. 在 CHANGELOG.md 添加与版本号一致的中英双语章节
# 2. 更新 project.yml：
#    MARKETING_VERSION: "0.14.2"
#    CURRENT_PROJECT_VERSION: "48"
xcodegen generate

# 3. 本地验证
make test
make verify-screenshots

# 4. 提交并推送 main
git add .
git commit -m "release: v0.14.2"
git push origin main

# 5. 打 tag 并推送，触发自动发布
git tag -a v0.14.2 -m "HaoPaste 0.14.2"
git push origin v0.14.2
```

查看与验证：

```bash
gh run list --workflow Release --limit 3
gh run watch <run-id> --exit-status
gh release view v0.14.2 --json url,assets,body
```

> 如果 Release 工作流失败，先修复代码并推送 `main`，再重新打 tag。已经发布但需要修补时，可以强制移动 tag 到新提交后重新触发工作流；工作流会更新已有 Release 并覆盖上传资产。

### 3.4 应用内更新提示

- `UpdateChecker` 每 24 小时最多自动检查一次，也可在设置 → 关于手动检查
- 默认从 GitHub Releases 读取最新版本与 DMG 资产
- 只提示并打开下载链接，不自动下载安装
- Release 说明会按当前语言提取摘要，去掉 Markdown 标记并限制长度
- 下载 DMG 后按双语安装说明操作；Gatekeeper 拦截时：
  **系统设置 → 隐私与安全性 → 安全性 → HaoPaste → 仍要打开**

## 4. 本地化与截图

### 4.1 本地化

- 中文源代码字符串是 key，通过 `L()` 查表
- 普通文案：`HaoPaste/en.lproj/Localizable.strings`、`HaoPaste/zh-Hans.lproj/Localizable.strings`
- 英文单复数：`HaoPaste/en.lproj/Localizable.stringsdict`、`HaoPaste/zh-Hans.lproj/Localizable.stringsdict`
- 语言选择：
  - 设置 → 通用 → 应用语言：跟随系统 / 简体中文 / English
  - 保存在 `settings.appLanguage`
  - 切换后通过「立即重启」生效
- 默认规则：中文系统使用简体中文，英文系统使用英文，其他系统回退英文
- 工程 development language 固定为 `en`

新增文案时必须同时更新中英文资源；带 `%d` 的计数文案还要更新两边 `.stringsdict`。

### 4.2 中英文截图

README 使用两套截图：

- 中文：`Docs/screenshot-*.png`
- 英文：`Docs/screenshot-*-en.png`

一键重新生成：

```bash
make screenshots
```

校验当前渲染结果是否与已提交基线一致：

```bash
make verify-screenshots
```

脚本会：

- 构建 Debug app
- 使用 `--language en` / `--language zh-Hans` 强制截图语言
- 使用 `HAOPASTE_RENDER_FIXED_NOW` 固定相对时间，并关闭动画（`HAOPASTE_RENDER_DISABLE_ANIMATIONS=1`），保证可重复
- 从 `DemoContent.swift` / `DebugRenderer.swift` 输出对应语言的示例数据

OCR 截图因为 `TextEditor` 光标闪烁，`verify-screenshots` 会跳过逐字节比较，但仍会生成。

新增或修改 UI 后，先人工确认截图，再运行 `make screenshots` 更新基线。

## 5. 交接给其他 AI

可直接复制下面这段：

```text
你接手维护 HaoPaste，一个 macOS 14+ 菜单栏剪贴板管理器。
仓库：https://github.com/AXing499/HaoPaste
本地工程：HaoPaste.xcodeproj，由 XcodeGen 从 project.yml 生成。

先阅读：
- README.md / README.en.md
- Docs/HANDOFF.md
- Docs/DEVELOPMENT.md
- CHANGELOG.md
- project.yml
- .github/workflows/ci.yml 与 .github/workflows/release.yml

当前约束：
- 使用中英双语本地化；中文源代码字符串是 key，通过 L() 查表。
- 语言设置：设置 → 通用 → 应用语言（跟随系统 / 简体中文 / English），重启后生效。
- 英文截图放在 Docs/screenshot-*-en.png，英文 README 必须引用这些英文截图。
- 不接入 Developer ID / 公证；保持 ad-hoc 签名，并在 DMG 和 Release 说明中保留 Gatekeeper 的「隐私与安全性 → 仍要打开」步骤。
- 发布说明必须同时有中文和英文；CHANGELOG.md 缺少对应版本章节时 Release 工作流会失败。
- 版本号必须同时更新 project.yml 的 MARKETING_VERSION 和 CURRENT_PROJECT_VERSION，并运行 xcodegen generate。

开发命令：
make project
make build
make test        # 120 个 XCTest，英文测试环境
make screenshots # 更新中英文截图
make verify-screenshots # 检查截图基线
make dmg

发布流程：
1. 在 CHANGELOG.md 添加 `## X.Y.Z — YYYY-MM-DD` 中英双语章节。
2. 修改 project.yml 的 MARKETING_VERSION / CURRENT_PROJECT_VERSION，运行 xcodegen generate。
3. 运行 make test 与 make verify-screenshots；必要时再运行：
   xcodebuild -project HaoPaste.xcodeproj -scheme HaoPaste -configuration Debug \
     -destination 'platform=macOS' -derivedDataPath .build test -testLanguage zh-Hans
4. 提交并推送 main。
5. 打 tag：git tag -a vX.Y.Z -m "HaoPaste X.Y.Z"
6. 推送 tag：git push origin vX.Y.Z
7. 用 gh run list --workflow Release 查看工作流，确认测试、DMG、CHANGELOG 提取和 Release 发布全部成功。
8. 下载 Release 中的 DMG，安装并确认版本号、双语 UI、更新提示和安装说明。

交付前检查：
- 中英文 UI 均无未翻译中文（英文环境）。
- README.en.md 的截图全部是 -en.png。
- CHANGELOG.md 有对应版本的中英双语章节。
- 120 个测试通过。
- Release 资产包含 DMG 和 SHA-256。
- 不修改无关功能，不删除现有测试，不引入第三方运行时依赖。
```
