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
    case history
    case privacy
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "通用"
        case .history: return "历史"
        case .privacy: return "隐私"
        case .about: return "关于"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "启动、快捷键与监听"
        case .history: return "记录容量、存储位置与清理"
        case .privacy: return "应用排除与内容类型"
        case .about: return "版本与隐私信息"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .history: return "clock.arrow.circlepath"
        case .privacy: return "hand.raised"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let manager: ClipboardManager

    @State private var selectedTab: SettingsTab = .general
    @State private var showClearUnpinnedAlert = false
    @State private var showClearAllAlert = false

    init(
        settings: AppSettings,
        manager: ClipboardManager,
        initialTab: SettingsTab = .general
    ) {
        self._settings = Bindable(wrappedValue: settings)
        self.manager = manager
        self._selectedTab = State(initialValue: initialTab)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.2.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
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
        .alert("清空未置顶记录？", isPresented: $showClearUnpinnedAlert) {
            Button("清空", role: .destructive) {
                manager.clearUnpinnedItems()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有未置顶记录都会被删除，此操作无法撤销。置顶记录会保留。")
        }
        .alert("清空全部记录？", isPresented: $showClearAllAlert) {
            Button("清空全部", role: .destructive) {
                manager.clearAllItems()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("包括置顶记录与图片缓存，此操作无法撤销。")
        }
        .onAppear {
            settings.refreshLaunchAtLoginStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            settings.refreshLaunchAtLoginStatus()
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
                Label("本地存储 · 无网络请求", systemImage: "lock.shield")
                Text("呼出快捷键 \(settings.hotKey.displayString)")
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
                case .history:
                    historyPage
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
        SettingsCard("启动") {
            SettingsRow(
                "登录时自动启动",
                subtitle: "登录 Mac 后在菜单栏常驻，随时可用"
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
                        Button("打开系统登录项设置…") {
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

        SettingsCard("全局快捷键") {
            SettingsRow(
                "呼出面板",
                subtitle: "点击后按下新的组合键；至少包含 ⌘、⌥ 或 ⌃"
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

        SettingsCard("监听") {
            SettingsRow(
                "监听剪贴板",
                subtitle: "暂停后不会读取或记录新的剪贴板内容"
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
    private var historyPage: some View {
        SettingsCard("记录上限") {
            SettingsRow(
                "未置顶记录上限",
                subtitle: "置顶记录不计入上限，也不会被自动清理"
            ) {
                Picker("", selection: $settings.maxUnpinnedItems) {
                    ForEach(AppSettings.historyLimitOptions, id: \.self) { limit in
                        Text("\(limit) 条").tag(limit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)
            }

            SettingsDivider()

            SettingsRow(
                "当前历史",
                subtitle: "包含文本、代码、链接、颜色与图片"
            ) {
                Text("\(manager.items.count) 条 · \(manager.pinnedCount) 条置顶")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }

        SettingsCard("存储") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("数据目录")
                        .font(.system(.body, design: .rounded))
                    Text(manager.storageDirectoryURL.path)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(manager.storageDirectoryURL.path)
                }

                Spacer(minLength: 10)

                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([
                        manager.storageDirectoryURL
                    ])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)
        }

        SettingsCard("备份与迁移") {
            actionRow(
                title: "导出历史",
                subtitle: "将记录与图片打包为未加密的 .zip，可用于备份或迁移到另一台 Mac",
                buttonTitle: "导出…",
                systemImage: "square.and.arrow.up",
                isEnabled: !manager.items.isEmpty
            ) {
                exportHistory()
            }

            SettingsDivider()

            actionRow(
                title: "导入历史",
                subtitle: "合并到现有历史；重复内容会自动跳过，置顶状态会保留",
                buttonTitle: "导入…",
                systemImage: "square.and.arrow.down",
                isEnabled: true
            ) {
                importHistory()
            }
        }

        SettingsCard("清理") {
            destructiveRow(
                title: "清空未置顶记录",
                subtitle: "保留置顶记录，删除其余历史与图片缓存",
                buttonTitle: "清空…",
                isEnabled: manager.hasUnpinnedItems
            ) {
                showClearUnpinnedAlert = true
            }

            SettingsDivider()

            destructiveRow(
                title: "清空全部记录",
                subtitle: "删除所有历史记录，包括置顶内容",
                buttonTitle: "清空全部…",
                isEnabled: !manager.items.isEmpty
            ) {
                showClearAllAlert = true
            }
        }
    }

    @ViewBuilder
    private var privacyPage: some View {
        SettingsCard("内容") {
            SettingsRow(
                "记录图片",
                subtitle: "关闭后，新复制的图片不会加入历史或生成缓存；已有图片不受影响"
            ) {
                Toggle("", isOn: $settings.capturesImages)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accentColor)
            }
        }

        SettingsCard("排除的应用") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("来自这些应用的复制内容不会写入历史")
                        .font(.system(.body, design: .rounded))
                    Text("只影响新的剪贴板内容；已记录的历史不会自动删除。")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Button {
                    chooseExcludedApplications()
                } label: {
                    Label("添加应用…", systemImage: "plus")
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
                    Text("尚未排除任何应用")
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
                            Text(application.bundleIdentifier ?? "按应用名称匹配")
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
                        .help("从排除列表移除")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
            }

            SettingsDivider()

            Text("隐藏类型、临时类型和常见密码管理器的过滤始终开启。")
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
                Text("版本 \(appVersion)（\(appBuild)）")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("快速、原生、键盘优先的剪贴板管理器。")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)

        SettingsCard("快捷键") {
            SettingsRow("呼出面板", subtitle: "在任意应用上方打开 HaoPaste") {
                Text(settings.hotKey.displayString)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }

            SettingsDivider()

            SettingsRow("快速复制", subtitle: "使用当前结果中的前九条") {
                Text("⌘1 – ⌘9")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }

        SettingsCard("隐私") {
            SettingsRow("数据存储", subtitle: "历史与图片仅保存在本机") {
                Image(systemName: "internaldrive")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            SettingsDivider()

            SettingsRow("网络访问", subtitle: "无账号、无遥测、无网络请求") {
                Image(systemName: "wifi.slash")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            SettingsDivider()

            SettingsRow("辅助功能权限", subtitle: "复制后需要手动按 ⌘V，因此不申请额外权限") {
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
            Button("退出 HaoPaste") {
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
        panel.title = "排除应用"
        panel.message = "选择不希望记录剪贴板内容的应用，可多选。"
        panel.prompt = "排除"
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
        panel.title = "导出历史"
        panel.message = "备份包含历史记录、置顶状态和图片，可迁移到另一台 Mac。"
        panel.prompt = "导出"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "HaoPaste-历史-\(archiveDateStamp()).zip"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let summary = try manager.exportHistory(to: url)
            showArchiveAlert(
                title: "导出完成",
                message: "已导出 \(summary.itemCount) 条记录、\(summary.imageCount) 张图片。\n\n\(url.path)",
                style: .informational
            )
        } catch {
            showArchiveAlert(
                title: "导出失败",
                message: error.localizedDescription,
                style: .warning
            )
        }
    }

    private func importHistory() {
        let panel = NSOpenPanel()
        panel.title = "导入历史"
        panel.message = "选择由 HaoPaste 导出的 .zip 备份文件。导入会合并到当前历史。"
        panel.prompt = "导入"
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let summary = try manager.importHistory(from: url)

            var message = "新增 \(summary.importedCount) 条，合并 \(summary.mergedPinnedCount) 条置顶，跳过 \(summary.skippedCount) 条重复或不可用内容。"
            if summary.trimmedCount > 0 {
                message += " 受当前历史上限影响，清理了 \(summary.trimmedCount) 条最早记录。"
            }

            showArchiveAlert(
                title: "导入完成",
                message: message,
                style: .informational
            )
        } catch {
            showArchiveAlert(
                title: "导入失败",
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
        alert.addButton(withTitle: "好")
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

private struct SettingsCard<Content: View>: View {
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

private struct SettingsRow<Control: View>: View {
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

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 14)
    }
}
