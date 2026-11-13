//
//  SettingsView.swift
//  HaoPaste
//
//  Native settings window for personalization and history management.
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case history
    case snippets
    case intelligence
    case privacy
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L("通用")
        case .shortcuts: return L("快捷键")
        case .history: return L("历史")
        case .snippets: return L("片段列表")
        case .intelligence: return L("智能")
        case .privacy: return L("隐私")
        case .about: return L("关于")
        }
    }

    var subtitle: String {
        switch self {
        case .general: return L("启动、快捷键与监听")
        case .shortcuts: return L("呼出、翻译、连续粘贴与截图翻译")
        case .history: return L("记录容量、存储位置与清理")
        case .snippets: return L("常用文本，一键复制")
        case .intelligence: return L("翻译引擎、语言与图片文字")
        case .privacy: return L("应用排除与内容类型")
        case .about: return L("版本与隐私信息")
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .shortcuts: return "keyboard"
        case .history: return "clock.arrow.circlepath"
        case .snippets: return "text.quote"
        case .intelligence: return "character.bubble"
        case .privacy: return "hand.raised"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(SnippetManager.self) private var snippetManager

    @Bindable var settings: AppSettings
    let manager: ClipboardManager
    let translationService: TranslationService

    @State private var selectedTab: SettingsTab = .general
    @State private var showClearUnpinnedAlert = false
    @State private var showClearAllAlert = false
    @State private var snippetEditor: SnippetEditorContext?
    @State private var isCheckingForUpdates = false

    init(
        settings: AppSettings,
        manager: ClipboardManager,
        translationService: TranslationService,
        initialTab: SettingsTab = .general
    ) {
        self._settings = Bindable(wrappedValue: settings)
        self.manager = manager
        self.translationService = translationService
        self._selectedTab = State(initialValue: initialTab)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.2.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var languageNeedsRestart: Bool {
        AppLanguage.code != AppLanguage.resolvedCode(for: settings.appLanguage)
    }

    private func relaunchApp() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundleURL.path]

        do {
            try task.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                NSApp.terminate(nil)
            }
        } catch {
            NSSound.beep()
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
                .overlay(Color.primary.opacity(0.06))
            content
        }
        .frame(width: 720, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(L("清空未置顶记录？"), isPresented: $showClearUnpinnedAlert) {
            Button(L("清空"), role: .destructive) {
                manager.clearUnpinnedItems()
            }
            Button(L("取消"), role: .cancel) {}
        } message: {
            Text(L("所有未置顶记录都会被删除，此操作无法撤销。置顶记录会保留。"))
        }
        .alert(L("清空全部记录？"), isPresented: $showClearAllAlert) {
            Button(L("清空全部"), role: .destructive) {
                manager.clearAllItems()
            }
            Button(L("取消"), role: .cancel) {}
        } message: {
            Text(L("包括置顶记录与图片缓存，此操作无法撤销。"))
        }
        .onAppear {
            settings.refreshLaunchAtLoginStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            settings.refreshLaunchAtLoginStatus()
        }
        .sheet(item: $snippetEditor) { context in
            SnippetEditorSheet(
                title: context.snippet?.title ?? "",
                content: context.snippet?.content ?? "",
                isEditing: context.snippet != nil,
                onSave: { title, content in
                    if let snippet = context.snippet {
                        snippetManager.update(snippet, title: title, content: content)
                    } else {
                        snippetManager.create(title: title, content: content)
                    }
                    snippetEditor = nil
                },
                onCancel: {
                    snippetEditor = nil
                }
            )
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text("HaoPaste")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("v\(appVersion)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 18)

            VStack(spacing: 3) {
                ForEach(SettingsTab.allCases) { tab in
                    SidebarTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(Theme.spring) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Label(L("本地存储 · 翻译按需联网"), systemImage: "lock.shield")
                Text(L("呼出快捷键 %@", settings.hotKey.displayString))
            }
            .font(.system(size: 10, design: .rounded))
            .foregroundStyle(.tertiary)
            .padding(16)
        }
        .frame(width: 184)
        .background(Color.primary.opacity(0.028))
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader

                switch selectedTab {
                case .general:
                    generalPage
                case .shortcuts:
                    shortcutsPage
                case .history:
                    historyPage
                case .snippets:
                    snippetsPage
                case .intelligence:
                    TranslationSettingsPage(
                        service: translationService,
                        appSettings: settings
                    )
                case .privacy:
                    privacyPage
                case .about:
                    aboutPage
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(selectedTab.title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(selectedTab.subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var generalPage: some View {
        SettingsCard(L("应用语言")) {
            SettingsRow(
                L("界面语言"),
                subtitle: L("选择应用界面语言；更改后需要重新启动 HaoPaste。")
            ) {
                Picker("", selection: $settings.appLanguage) {
                    ForEach(AppLanguagePreference.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 160)
            }

            if languageNeedsRestart {
                SettingsDivider()

                HStack(spacing: 10) {
                    Label(L("重新启动后生效"), systemImage: "arrow.clockwise")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.orange)

                    Spacer(minLength: 8)

                    Button(L("立即重启")) {
                        relaunchApp()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 11)
            }
        }

        if #available(macOS 26.0, *) {
            SettingsCard(L("外观")) {
                SettingsRow(
                    L("Liquid Glass 效果"),
                    subtitle: L(
                        "使用 macOS 26 的系统玻璃材质；关闭后使用轻量磨砂材质，可降低 GPU 占用"
                    )
                ) {
                    Toggle(
                        "",
                        isOn: $settings.liquidGlassEnabled
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accentColor)
                }

                SettingsDivider()

                SettingsRow(
                    L("玻璃通透度"),
                    subtitle: L(
                        "磨砂更稳重，通透更接近系统玻璃；仅影响 Liquid Glass 区域"
                    )
                ) {
                    Picker("", selection: $settings.glassTransparency) {
                        ForEach(GlassTransparency.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                    .disabled(!settings.liquidGlassEnabled)
                }
            }
        }


        SettingsCard(L("启动")) {
            SettingsRow(
                L("登录时自动启动"),
                subtitle: L("登录 Mac 后在菜单栏常驻，随时可用")
            ) {
                Toggle("", isOn: launchAtLoginBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accentColor)
            }

            if let error = settings.launchAtLoginError {
                SettingsDivider()
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)

                    if settings.launchAtLoginRequiresApproval {
                        Button(L("打开系统登录项设置…")) {
                            settings.openLoginItemsSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 11)
            }
        }

        SettingsCard(L("全局快捷键")) {
            SettingsRow(
                L("呼出面板"),
                subtitle: L("点击后按下新的组合键；至少包含 ⌘、⌥ 或 ⌃")
            ) {
                ShortcutRecorderView(
                    configuration: settings.hotKey,
                    registrationError: settings.hotKeyRegistrationError,
                    onRecord: { configuration in
                        settings.hotKey = configuration
                    },
                    onReset: {
                        settings.resetHotKeyToDefault()
                    }
                )
            }
        }

        SettingsCard(L("剪贴板挂架")) {
            SettingsRow(
                L("启用挂架"),
                subtitle: L("鼠标停在所选屏幕边缘的中间区域即可展开；点击卡片复制，鼠标离开后自动收起")
            ) {
                Toggle("", isOn: $settings.shelfEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accentColor)
            }

            SettingsDivider()

            SettingsRow(
                L("显示位置"),
                subtitle: L("顶部从菜单栏中间展开；左侧 / 右侧从屏幕边缘中间展开")
            ) {
                Picker("", selection: $settings.shelfEdge) {
                    ForEach(ClipboardShelfEdge.allCases) { edge in
                        Text(edge.title).tag(edge)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 100)
                .disabled(!settings.shelfEnabled)
            }

            SettingsDivider()

            SettingsRow(
                L("加载数量"),
                subtitle: L("最多加载的卡片数量；超出屏幕后可用触控板或滚轮滑动查看，也可选择「不限」")
            ) {
                Picker("", selection: $settings.shelfItemLimit) {
                    ForEach(AppSettings.shelfItemLimitOptions, id: \.self) { limit in
                        Text(
                            limit < 0 ? L("不限") : L("%d 条", limit)
                        )
                        .tag(limit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 100)
                .disabled(!settings.shelfEnabled)
            }

            SettingsDivider()

            SettingsRow(
                L("卡片下落时间"),
                subtitle: L("点击夹子删除卡片时的下落动画时长；夹子会单独松开和掉落")
            ) {
                Picker("", selection: $settings.shelfCardFallDuration) {
                    ForEach(AppSettings.shelfCardFallDurationOptions, id: \.self) { duration in
                        Text(fallDurationLabel(duration))
                            .tag(duration)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 100)
                .disabled(!settings.shelfEnabled)
            }
        }

        SettingsCard(L("复制行为")) {
            SettingsRow(
                L("主面板复制后"),
                subtitle: L("点击条目复制后，主面板保持打开、立即收起或延迟收起")
            ) {
                Picker("", selection: $settings.panelCopyBehavior) {
                    ForEach(CopyBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 200)
            }

            SettingsDivider()

            SettingsRow(
                L("挂架复制后"),
                subtitle: L("点击卡片复制后，挂架保持展开、立即收起或延迟收起")
            ) {
                Picker("", selection: $settings.shelfCopyBehavior) {
                    ForEach(CopyBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 200)
            }

            SettingsDivider()

            SettingsRow(
                L("富文本只复制纯文本"),
                subtitle: L("复制富文本条目时只写入纯文本，不带 RTF / HTML 格式")
            ) {
                Toggle("", isOn: $settings.copyPlainTextOnly)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accentColor)
            }
        }

        SettingsCard(L("翻译")) {
            SettingsRow(
                L("打开面板时翻译最新记录"),
                subtitle: L("默认关闭；仅对与目标语言不同的最新文本自动执行；每条记录只自动翻译一次，图片不会自动翻译")
            ) {
                Toggle("", isOn: $settings.autoTranslateLatestOnOpen)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accentColor)
            }
        }

        SettingsCard(L("监听")) {
            SettingsRow(
                L("监听剪贴板"),
                subtitle: L("暂停后不会读取或记录新的剪贴板内容")
            ) {
                Toggle("", isOn: monitoringBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accentColor)
            }
        }
    }

    @ViewBuilder
    private var shortcutsPage: some View {
        SettingsCard(L("全局快捷键")) {
            SettingsRow(
                L("呼出主面板"),
                subtitle: L("从任意应用打开 HaoPaste 主面板")
            ) {
                ShortcutRecorderView(
                    configuration: settings.hotKey,
                    registrationError: settings.hotKeyRegistrationError,
                    onRecord: { settings.hotKey = $0 },
                    onReset: { settings.resetHotKeyToDefault() },
                    resetConfiguration: .default
                )
            }

            SettingsDivider()

            SettingsRow(
                L("快捷翻译剪贴板"),
                subtitle: L("翻译当前剪贴板中的文本")
            ) {
                ShortcutRecorderView(
                    configuration: settings.translationHotKey,
                    registrationError: settings.translationHotKeyRegistrationError,
                    onRecord: { settings.translationHotKey = $0 },
                    onReset: { settings.resetTranslationHotKeyToDefault() },
                    resetConfiguration: .translationDefault
                )
            }

            SettingsDivider()

            SettingsRow(
                L("连续粘贴下一项"),
                subtitle: L("开始连续粘贴后，切换到队列中的下一项")
            ) {
                ShortcutRecorderView(
                    configuration: settings.pasteStackHotKey,
                    registrationError: settings.pasteStackHotKeyRegistrationError,
                    onRecord: { settings.pasteStackHotKey = $0 },
                    onReset: { settings.resetPasteStackHotKeyToDefault() },
                    resetConfiguration: .pasteStackNextDefault
                )
            }

            SettingsDivider()

            SettingsRow(
                L("截图翻译"),
                subtitle: L("框选屏幕区域，本地识别文字后翻译")
            ) {
                ShortcutRecorderView(
                    configuration: settings.screenshotHotKey,
                    registrationError: settings.screenshotHotKeyRegistrationError,
                    onRecord: { settings.screenshotHotKey = $0 },
                    onReset: { settings.resetScreenshotHotKeyToDefault() },
                    resetConfiguration: .screenshotTranslationDefault
                )
            }
        }

        Text(
            L(
                "快捷键使用全局 Carbon 注册；如果组合被其他应用占用，会自动恢复上一个可用快捷键并显示提示。"
            )
        )
        .font(.system(size: 9.5, design: .rounded))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var historyPage: some View {
        SettingsCard(L("记录上限")) {
            SettingsRow(
                L("未置顶记录上限"),
                subtitle: L("置顶记录不计入上限，也不会被自动清理")
            ) {
                Picker("", selection: $settings.maxUnpinnedItems) {
                    ForEach(AppSettings.historyLimitOptions, id: \.self) { limit in
                        Text(L("%d 条", limit)).tag(limit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            SettingsDivider()

            SettingsRow(
                L("当前历史"),
                subtitle: L("包含文本、代码、链接、颜色、图片与文件")
            ) {
                Text(
                    L(
                        "历史：%d 条 · 置顶：%d 条",
                        manager.items.count,
                        manager.pinnedCount
                    )
                )
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }

        SettingsCard(L("最近删除")) {
            SettingsRow(
                L("保留时间"),
                subtitle: L("删除的记录会在这里保留一段时间，到期后自动清除")
            ) {
                Picker("", selection: $settings.trashRetentionDays) {
                    ForEach(AppSettings.trashRetentionOptions, id: \.self) { days in
                        Text(L("%d 天", days)).tag(days)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            SettingsDivider()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("最近删除"))
                        .font(.system(.body, design: .rounded))
                    Text(
                        L(
                            "当前保留 %d 条记录",
                            manager.trashedItems.count
                        )
                    )
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Button(L("清空最近删除…")) {
                    confirmEmptyTrash()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(manager.trashedItems.isEmpty)
            }
            .padding(14)
        }

        SettingsCard(L("存储")) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("数据目录"))
                        .font(.system(.body, design: .rounded))
                    Text(manager.storageDirectoryURL.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(manager.storageDirectoryURL.path)
                }

                Spacer(minLength: 10)

                Button(L("在 Finder 中显示")) {
                    NSWorkspace.shared.activateFileViewerSelecting([
                        manager.storageDirectoryURL
                    ])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)
        }

        SettingsCard(L("备份与迁移")) {
            actionRow(
                title: L("导出历史"),
                subtitle: L("将记录与图片打包为未加密的 .zip，可用于备份或迁移到另一台 Mac"),
                buttonTitle: L("导出…"),
                systemImage: "square.and.arrow.up",
                isEnabled: !manager.items.isEmpty
            ) {
                exportHistory()
            }

            SettingsDivider()

            actionRow(
                title: L("导入历史"),
                subtitle: L("合并到现有历史；重复内容会自动跳过，置顶状态会保留"),
                buttonTitle: L("导入…"),
                systemImage: "square.and.arrow.down",
                isEnabled: true
            ) {
                importHistory()
            }
        }

        SettingsCard(L("清理")) {
            destructiveRow(
                title: L("清空未置顶记录"),
                subtitle: L("保留置顶记录，删除其余历史与图片缓存"),
                buttonTitle: L("清空…"),
                isEnabled: manager.hasUnpinnedItems
            ) {
                showClearUnpinnedAlert = true
            }

            SettingsDivider()

            destructiveRow(
                title: L("清空全部记录"),
                subtitle: L("删除所有历史记录，包括置顶内容"),
                buttonTitle: L("清空全部…"),
                isEnabled: !manager.items.isEmpty
            ) {
                showClearAllAlert = true
            }
        }
    }

    @ViewBuilder
    private var snippetsPage: some View {
        SettingsCard(L("片段列表")) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("常用文本与模板"))
                        .font(.system(.body, design: .rounded))
                    Text(L("在面板的「片段」标签中一键复制；片段不会写入剪贴板历史。"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Button {
                    snippetEditor = SnippetEditorContext(snippet: nil)
                } label: {
                    Label(L("新建片段…"), systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)

            SettingsDivider()

            if snippetManager.snippets.isEmpty {
                HStack(spacing: 9) {
                    Image(systemName: "text.quote")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                    Text(L("还没有片段。创建后可在面板中快速复制。"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(14)
            } else {
                ForEach(Array(snippetManager.snippets.enumerated()), id: \.element.id) { index, snippet in
                    if index > 0 {
                        SettingsDivider()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 30, height: 30)
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.08))
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.title)
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .lineLimit(1)
                            Text(snippet.contentPreview)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Text(L("%d 字符", snippet.characterCount))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.tertiary)

                        RoundIconButton(
                            symbolName: "pencil",
                            help: L("编辑片段")
                        ) {
                            snippetEditor = SnippetEditorContext(snippet: snippet)
                        }

                        RoundIconButton(
                            symbolName: "trash",
                            help: L("删除片段")
                        ) {
                            confirmDeleteSnippet(snippet)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
            }

            SettingsDivider()

            Text(L("复制片段后会关闭面板并返回之前的应用，不会创建新的历史记录。"))
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        SettingsCard(L("使用提示")) {
            SettingsRow(
                L("面板快速访问"),
                subtitle: L("按 ⌥⌘V 打开面板，切换到「片段」标签，用方向键选择后按 ↵ 复制。")
            ) {
                Image(systemName: "keyboard")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func checkForUpdates() {
        let raw = settings.updateFeedURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let url = URL(string: raw) else {
            let alert = NSAlert()
            alert.messageText = L("还没有更新源")
            alert.informativeText = L("请先在「更新清单地址」中填写返回版本信息的 JSON 地址。")
            alert.alertStyle = .informational
            alert.addButton(withTitle: L("好"))
            alert.runModal()
            return
        }

        isCheckingForUpdates = true
        Task { @MainActor in
            defer { isCheckingForUpdates = false }
            do {
                let manifest = try await UpdateChecker.fetch(from: url)
                if UpdateChecker.isNewer(
                    version: manifest.version,
                    than: appVersion
                ) {
                    UpdateChecker.presentUpdate(
                        manifest,
                        currentVersion: appVersion
                    )
                } else {
                    UpdateChecker.presentNoUpdate(
                        currentVersion: appVersion
                    )
                }
            } catch {
                UpdateChecker.presentError(error)
            }
        }
    }

    private func fallDurationLabel(_ duration: Double) -> String {
        var value = String(format: "%.2f", duration)
        while value.hasSuffix("0") {
            value.removeLast()
        }
        if value.hasSuffix(".") {
            value.removeLast()
        }
        return L("%@ 秒", value)
    }

    private func confirmEmptyTrash() {
        guard !manager.trashedItems.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = L("清空最近删除？")
        alert.informativeText = L("所有最近删除的记录将被永久删除，此操作无法撤销。")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("清空"))
        alert.addButton(withTitle: L("取消"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        manager.emptyTrash()
    }

    private func confirmDeleteSnippet(_ snippet: Snippet) {
        let alert = NSAlert()
        alert.messageText = L("删除片段「%@」？", snippet.title)
        alert.informativeText = L("此操作无法撤销。")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("删除"))
        alert.addButton(withTitle: L("取消"))

        if alert.runModal() == .alertFirstButtonReturn {
            snippetManager.delete(snippet)
        }
    }

    @ViewBuilder
    private var privacyPage: some View {
        SettingsCard(L("内容")) {
            SettingsRow(
                L("记录图片"),
                subtitle: L("关闭后，新复制的图片不会加入历史或生成缓存；已有图片不受影响")
            ) {
                Toggle("", isOn: $settings.capturesImages)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accentColor)
            }
        }

        SettingsCard(L("排除的应用")) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("来自这些应用的复制内容不会写入历史"))
                        .font(.system(.body, design: .rounded))
                    Text(L("只影响新的剪贴板内容；已记录的历史不会自动删除。"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Button {
                    chooseExcludedApplications()
                } label: {
                    Label(L("添加应用…"), systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)

            SettingsDivider()

            if settings.excludedApplications.isEmpty {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.shield")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                    Text(L("尚未排除任何应用"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(14)
            } else {
                ForEach(Array(settings.excludedApplications.enumerated()), id: \.element.id) { index, application in
                    if index > 0 {
                        SettingsDivider()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "app")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                            }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(application.name)
                                .font(.system(.body, design: .rounded))
                            Text(application.bundleIdentifier ?? L("按应用名称匹配"))
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 10)

                        Button {
                            settings.removeExcludedApplication(application)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .help(L("从排除列表移除"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
            }

            SettingsDivider()

            Text(L("隐藏类型、临时类型和常见密码管理器的过滤始终开启。"))
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(.tertiary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var aboutPage: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("HaoPaste")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(L("版本 %@（%@）", appVersion, appBuild))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(L("快速、原生、键盘优先的剪贴板管理器。"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)

        SettingsCard(L("更新")) {
            SettingsRow(
                L("检查更新"),
                subtitle: L("只检查新版本并打开下载链接，不会自动安装")
            ) {
                Button(isCheckingForUpdates ? L("检查中…") : L("检查更新…")) {
                    checkForUpdates()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isCheckingForUpdates)
            }

            SettingsDivider()

            SettingsRow(
                L("更新清单地址"),
                subtitle: L("默认使用 GitHub Releases；清空地址可关闭自动检查")
            ) {
                TextField(
                    "https://example.com/hao-paste/latest.json",
                    text: $settings.updateFeedURL
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 280)
            }
        }

        SettingsCard(L("快捷键")) {
            SettingsRow(L("呼出面板"), subtitle: L("在任意应用上方打开 HaoPaste")) {
                Text(settings.hotKey.displayString)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }

            SettingsDivider()

            SettingsRow(L("快速复制"), subtitle: L("使用当前结果中的前九条")) {
                Text("⌘1 – ⌘9")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }

        SettingsCard(L("隐私")) {
            SettingsRow(L("数据存储"), subtitle: L("历史与图片仅保存在本机")) {
                Image(systemName: "internaldrive")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            SettingsDivider()

            SettingsRow(L("网络访问"), subtitle: L("默认不联网；仅在线翻译时发送当前文本")) {
                Image(systemName: "network")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            SettingsDivider()

            SettingsRow(L("辅助功能权限"), subtitle: L("复制后需要手动按 ⌘V，因此不申请额外权限")) {
                Image(systemName: "checkmark.shield")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }

        HStack {
            Text("© 2026 Hao. All rights reserved.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.tertiary)
            Spacer()
            Button(L("查看首次引导")) {
                NotificationCenter.default.post(
                    name: .haopasteShowOnboarding,
                    object: nil
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button(L("退出 HaoPaste")) {
                NSApp.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.top, 2)
    }

    // MARK: - Actions

    private func chooseExcludedApplications() {
        let panel = NSOpenPanel()
        panel.title = L("排除应用")
        panel.message = L("选择不希望记录剪贴板内容的应用，可多选。")
        panel.prompt = L("排除")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK else { return }

        let applications = panel.urls.map { url -> ExcludedApplication in
            let bundle = Bundle(url: url)
            let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent

            return ExcludedApplication(
                bundleIdentifier: bundle?.bundleIdentifier,
                name: name
            )
        }

        settings.addExcludedApplications(applications)
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.title = L("导出历史")
        panel.message = L("备份包含历史记录、置顶状态和图片，可迁移到另一台 Mac。")
        panel.prompt = L("导出")
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = L(
            "HaoPaste-历史-%@.zip",
            archiveDateStamp()
        )

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let summary = try manager.exportHistory(
                to: url,
                snippets: snippetManager.snippets
            )
            showArchiveAlert(
                title: L("导出完成"),
                message: L(
                    "已导出 %d 条记录、%d 张图片、%d 个片段。\n\n%@",
                    summary.itemCount,
                    summary.imageCount,
                    summary.snippetCount,
                    url.path
                ),
                style: .informational
            )
        } catch {
            showArchiveAlert(
                title: L("导出失败"),
                message: error.localizedDescription,
                style: .warning
            )
        }
    }

    private func importHistory() {
        let panel = NSOpenPanel()
        panel.title = L("导入历史")
        panel.message = L("选择由 HaoPaste 导出的 .zip 备份文件。导入会合并到当前历史。")
        panel.prompt = L("导入")
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let summary = try manager.importHistory(from: url)
            let snippetMerge = snippetManager.mergeImported(summary.snippets)

            var message = L(
                "新增 %d 条，合并 %d 条置顶，跳过 %d 条重复或不可用内容。",
                summary.importedCount,
                summary.mergedPinnedCount,
                summary.skippedCount
            )
            if summary.trimmedCount > 0 {
                message += L(
                    " 受当前历史上限影响，清理了 %d 条最早记录。",
                    summary.trimmedCount
                )
            }
            if snippetMerge.added > 0 || snippetMerge.updated > 0 {
                message += L(
                    " 片段新增 %d 个，更新 %d 个。",
                    snippetMerge.added,
                    snippetMerge.updated
                )
            }

            showArchiveAlert(
                title: L("导入完成"),
                message: message,
                style: .informational
            )
        } catch {
            showArchiveAlert(
                title: L("导入失败"),
                message: error.localizedDescription,
                style: .warning
            )
        }
    }

    private func showArchiveAlert(
        title: String,
        message: String,
        style: NSAlert.Style
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: L("好"))
        alert.runModal()
    }

    private func archiveDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    // MARK: - Bindings

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLoginEnabled },
            set: { settings.setLaunchAtLogin($0) }
        )
    }

    private var monitoringBinding: Binding<Bool> {
        Binding(
            get: { !manager.isMonitoringPaused },
            set: { manager.setMonitoringPaused(!$0) }
        )
    }

    // MARK: - Helpers

    private func actionRow(
        title: String,
        subtitle: String,
        buttonTitle: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            Button(action: action) {
                Label(buttonTitle, systemImage: systemImage)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!isEnabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func destructiveRow(
        title: String,
        subtitle: String,
        buttonTitle: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

// MARK: - Components

private struct SidebarTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: tab.symbolName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 16)

                Text(tab.title)
                    .font(.system(.body, design: .rounded).weight(.medium))

                Spacer(minLength: 0)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.16), lineWidth: 0.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        .animation(reduceMotion ? nil : Theme.spring, value: isSelected)
    }

    private var foregroundColor: Color {
        if isSelected {
            return .accentColor
        }
        return isHovering ? .primary : .secondary
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.10)
        }
        return isHovering ? Color.primary.opacity(0.05) : .clear
    }
}

struct SettingsCard<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }

            VStack(spacing: 0) {
                content
            }
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let control: Control

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 14)
    }
}


private struct SnippetEditorContext: Identifiable {
    let id = UUID()
    let snippet: Snippet?
}

struct SnippetEditorSheet: View {
    let isEditing: Bool
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var content: String
    @FocusState private var titleFocused: Bool

    init(
        title: String,
        content: String,
        isEditing: Bool,
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.isEditing = isEditing
        self.onSave = onSave
        self.onCancel = onCancel
        self._title = State(initialValue: title)
        self._content = State(initialValue: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? L("编辑片段") : L("新建片段"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            VStack(alignment: .leading, spacing: 6) {
                Text(L("名称"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField(L("例如：工作邮箱"), text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .rounded))
                    .focused($titleFocused)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L("内容"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                TextEditor(text: $content)
                    .font(.system(size: 13, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(7)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
                    .frame(minHeight: 170)
            }

            HStack {
                Spacer()

                Button(L("取消"), action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button(isEditing ? L("保存") : L("创建")) {
                    onSave(title, content)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 528, height: 400)
        .onAppear {
            titleFocused = true
        }
    }
}
