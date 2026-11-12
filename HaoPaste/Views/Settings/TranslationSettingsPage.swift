//
//  TranslationSettingsPage.swift
//  HaoPaste
//
//  Settings for translation engines, language defaults and API credentials.
//

import AppKit
import SwiftUI

struct TranslationSettingsPage: View {
    let service: TranslationService
    @Bindable var settings: TranslationSettingsStore
    @Bindable var appSettings: AppSettings

    @State private var accessibilityTrusted = SelectionTranslationAccess.isTrusted

    @Environment(OCRService.self) private var ocrService
    @State private var configuringProvider: TranslationProviderID?
    @State private var showClearOCRCacheAlert = false

    init(service: TranslationService, appSettings: AppSettings) {
        self.service = service
        self._settings = Bindable(wrappedValue: service.settings)
        self._appSettings = Bindable(wrappedValue: appSettings)
    }

    var body: some View {
        SettingsCard(L("语言")) {
            SettingsRow(
                L("默认目标语言"),
                subtitle: L("新翻译默认使用此语言；原文已是该语言时会自动切换中英方向")
            ) {
                Picker("", selection: $settings.targetLanguageID) {
                    ForEach(TranslationLanguage.all) { language in
                        Text(language.name).tag(language.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            SettingsDivider()

            SettingsRow(
                L("在线翻译授权"),
                subtitle: consentSubtitle
            ) {
                Button(L("重新授权")) {
                    settings.resetConsent()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(settings.consentedProviderIDs.isEmpty)
            }
        }

        SettingsCard(L("划词翻译")) {
            SettingsRow(
                L("启用划词翻译"),
                subtitle: L("选中文本后显示翻译图标；默认关闭，启用需要辅助功能权限。")
            ) {
                Toggle("", isOn: $appSettings.selectionTranslationEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accentColor)
                    .onChange(of: appSettings.selectionTranslationEnabled) { _, enabled in
                        if enabled, !SelectionTranslationAccess.isTrusted {
                            _ = SelectionTranslationAccess.request()
                        }
                        accessibilityTrusted = SelectionTranslationAccess.isTrusted
                    }
            }

            if appSettings.selectionTranslationEnabled {
                SettingsDivider()

                HStack(spacing: 10) {
                    Image(
                        systemName: accessibilityTrusted
                            ? "checkmark.shield"
                            : "lock.shield"
                    )
                    .foregroundStyle(
                        accessibilityTrusted ? Color.accentColor : Color.orange
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            accessibilityTrusted
                                ? L("辅助功能权限已授权")
                                : L("需要辅助功能权限")
                        )
                        .font(.system(size: 11, weight: .medium, design: .rounded))

                        Text(
                            L(
                                "仅在启用划词翻译时读取当前选中文本；不会读取其他内容。"
                            )
                        )
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundStyle(.secondary)

                        if !accessibilityTrusted {
                            Text(
                                L(
                                    "如果系统设置中已勾选 HaoPaste 但仍显示此提示，请先移除 HaoPaste，再重新添加当前版本。"
                                )
                            )
                            .font(.system(size: 9.5, design: .rounded))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 8)

                    if !accessibilityTrusted {
                        Button(L("打开辅助功能设置…")) {
                            SelectionTranslationAccess.openSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }

            SettingsDivider()

            Text(
                L(
                    "由于当前使用 ad-hoc 签名，每次安装新版本后通常需要重新授予辅助功能权限。"
                )
            )
            .font(.system(size: 9.5, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }

        SettingsCard(L("截图翻译")) {
            SettingsRow(
                L("截图翻译快捷键"),
                subtitle: L(
                    "框选屏幕区域并在本机识别文字；识别后可点击「翻译」。需要屏幕录制权限。"
                )
            ) {
                Text(
                    HotKeyConfiguration.screenshotTranslationDefault.displayString
                )
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background {
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                }
            }

            SettingsDivider()

            SettingsRow(
                L("屏幕录制权限"),
                subtitle: L(
                    "首次使用会请求权限；如果截图失败，请在系统设置中允许 HaoPaste。"
                )
            ) {
                Button(L("打开屏幕录制设置…")) {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            SettingsDivider()

            Text(
                L(
                    "由于当前使用 ad-hoc 签名，每次安装新版本后通常需要重新授予屏幕录制权限。"
                )
            )
            .font(.system(size: 9.5, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }

        SettingsCard(L("识图")) {
            SettingsRow(
                L("识别语言"),
                subtitle: L("自动检测适合混合语言截图；指定语言可提高特定语种准确率")
            ) {
                Picker(
                    "",
                    selection: Binding(
                        get: { ocrService.recognitionLanguage },
                        set: { ocrService.recognitionLanguage = $0 }
                    )
                ) {
                    ForEach(OCRRecognitionLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            SettingsDivider()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("识图缓存"))
                        .font(.system(.body, design: .rounded))
                    Text(L("识别结果按图片与语言缓存在本机，不上传；清除后需要重新识别。"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Button(L("清除识图缓存")) {
                    showClearOCRCacheAlert = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)
        }

        SettingsCard(L("引擎优先级")) {
            ForEach(
                Array(settings.providerOrder.enumerated()),
                id: \.element
            ) { index, id in
                providerRow(
                    id,
                    index: index,
                    count: settings.providerOrder.count
                )

                if index < settings.providerOrder.count - 1 {
                    SettingsDivider()
                }
            }
        }

        SettingsCard(L("说明")) {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    L("只有点击翻译时才会把当前文本发送给启用的在线引擎。图片、历史和其他内容不会上传。"),
                    systemImage: "lock.shield"
                )

                Label(
                    L("Google、Bing、DeepL 的非官方接口没有公开契约，可能限流、失效或违反服务条款；请勿翻译敏感内容。"),
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.orange)

                Label(
                    L("图片文字识别在本地使用 Vision 完成，识别结果缓存在本机、不会上传图片，可在上方清除。"),
                    systemImage: "text.viewfinder"
                )

                Label(
                    L("官方 API 凭证保存在 macOS 钥匙串，不写入历史、日志或备份文件。"),
                    systemImage: "key"
                )
            }
            .font(.system(size: 10.5, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            accessibilityTrusted = SelectionTranslationAccess.isTrusted
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            accessibilityTrusted = SelectionTranslationAccess.isTrusted
        }
        .sheet(item: $configuringProvider) { id in
            TranslationProviderConfigSheet(
                service: service,
                providerID: id
            )
        }
        .alert(L("清除识图缓存？"), isPresented: $showClearOCRCacheAlert) {
            Button(L("清除"), role: .destructive) {
                ocrService.clearCache()
            }
            Button(L("取消"), role: .cancel) {}
        } message: {
            Text(L("已识别的图片文字缓存会被删除，下次识别需要重新运行 Vision。"))
        }
    }

    private func providerRow(
        _ id: TranslationProviderID,
        index: Int,
        count: Int
    ) -> some View {
        let descriptor = id.descriptor
        let isConfigured = providerIsConfigured(id, descriptor: descriptor)

        return HStack(spacing: 10) {
            Image(systemName: descriptor.kind == .official ? "checkmark.shield" : "network")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    descriptor.kind == .official
                        ? Color.accentColor
                        : Color.orange
                )
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            descriptor.kind == .official
                                ? Color.accentColor.opacity(0.08)
                                : Color.orange.opacity(0.09)
                        )
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(descriptor.name)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .lineLimit(1)

                    Text(descriptor.kind.label)
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            descriptor.kind == .official
                                ? Color.secondary
                                : Color.orange
                        )
                        .padding(.horizontal, 5)
                        .frame(height: 15)
                        .background {
                            Capsule()
                                .fill(
                                    descriptor.kind == .official
                                        ? Color.primary.opacity(0.05)
                                        : Color.orange.opacity(0.10)
                                )
                        }
                }

                Text(providerSubtitle(descriptor, isConfigured: isConfigured))
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                Button {
                    settings.moveProvider(id, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .help(L("提高优先级"))

                Button {
                    settings.moveProvider(id, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == count - 1)
                .help(L("降低优先级"))
            }
            .frame(width: 46)
            .foregroundStyle(.secondary)

            Group {
                if descriptor.requiresConfiguration {
                    Button(isConfigured ? L("修改…") : L("配置…")) {
                        configuringProvider = id
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Text(L("无需配置"))
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 96, alignment: .trailing)

            Toggle(
                "",
                isOn: Binding(
                    get: { settings.isEnabled(id) },
                    set: { settings.setEnabled($0, for: id) }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(Color.accentColor)
            .disabled(descriptor.requiresConfiguration && !isConfigured)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func providerIsConfigured(
        _ id: TranslationProviderID,
        descriptor: TranslationProviderDescriptor
    ) -> Bool {
        guard descriptor.requiresConfiguration else { return true }
        // Attribute-only lookup avoids prompting for the login password just
        // because the translation settings page was opened.
        return service.credentials.hasCredentials(for: id)
    }

    private func providerSubtitle(
        _ descriptor: TranslationProviderDescriptor,
        isConfigured: Bool
    ) -> String {
        guard descriptor.requiresConfiguration else {
            return descriptor.subtitle
        }
        return isConfigured
            ? L("已配置 · %@", descriptor.subtitle)
            : descriptor.subtitle
    }

    private var consentSubtitle: String {
        guard !settings.consentedProviderIDs.isEmpty else {
            return L("首次翻译时会询问一次；授权后不会再次打断")
        }

        let names = settings.providerOrder
            .filter { settings.consentedProviderIDs.contains($0) }
            .map(\.descriptor.name)
            .joined(separator: L("、"))
        return names.isEmpty ? L("尚未授权") : L("已授权：%@", names)
    }
}

private struct TranslationProviderConfigSheet: View {
    let service: TranslationService
    let providerID: TranslationProviderID

    @Environment(\.dismiss) private var dismiss
    @State private var credentials: TranslationCredentials
    @State private var isTesting = false
    @State private var testMessage: String?
    @State private var testSucceeded = false

    init(service: TranslationService, providerID: TranslationProviderID) {
        self.service = service
        self.providerID = providerID
        self._credentials = State(
            initialValue: service.credentials.credentials(for: providerID)
                ?? TranslationCredentials()
        )
    }

    private var descriptor: TranslationProviderDescriptor {
        providerID.descriptor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L("配置 %@", descriptor.name))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(descriptor.subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(descriptor.requiredFields, id: \.self) { field in
                    credentialField(field)
                }
            }

            if let testMessage {
                Label(
                    testMessage,
                    systemImage: testSucceeded ? "checkmark.circle" : "exclamationmark.triangle"
                )
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(testSucceeded ? Color.green : Color.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            Text(L("凭证保存在 macOS 钥匙串，不会进入导出备份。测试会产生一次真实翻译请求。"))
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 8) {
                Button {
                    testConnection()
                } label: {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(L("测试连接"))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isTesting || !credentials.hasValues(for: descriptor))

                if service.credentials.hasCredentials(for: providerID) {
                    Button(L("清除凭证"), role: .destructive) {
                        clearCredentials()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                Spacer()

                Button(L("取消")) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(L("保存")) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.accentColor)
                .disabled(!credentials.hasValues(for: descriptor))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    @ViewBuilder
    private func credentialField(_ field: TranslationCredentialField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.title)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if field.isSecret {
                SecureField(field.placeholder, text: binding(for: field))
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(field.placeholder, text: binding(for: field))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func binding(for field: TranslationCredentialField) -> Binding<String> {
        Binding(
            get: { credentials.value(for: field) },
            set: { credentials.set($0, for: field) }
        )
    }

    private func testConnection() {
        isTesting = true
        testMessage = nil

        Task {
            do {
                try await service.testProvider(
                    providerID,
                    credentials: credentials
                )
                testSucceeded = true
                testMessage = L("连接成功，翻译接口可用。")
            } catch {
                testSucceeded = false
                testMessage = error.localizedDescription
            }
            isTesting = false
        }
    }

    private func save() {
        service.credentials.save(credentials, for: providerID)

        if credentials.hasValues(for: descriptor) {
            service.settings.setEnabled(true, for: providerID)
        }
        dismiss()
    }

    private func clearCredentials() {
        service.credentials.remove(for: providerID)
        service.settings.setEnabled(false, for: providerID)
        credentials = TranslationCredentials()
        testMessage = nil
    }
}
