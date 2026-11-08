//
//  TranslationSettingsPage.swift
//  HaoPaste
//
//  Settings for translation engines, language defaults and API credentials.
//

import SwiftUI

struct TranslationSettingsPage: View {
    let service: TranslationService
    @Bindable var settings: TranslationSettingsStore

    @State private var configuringProvider: TranslationProviderID?

    init(service: TranslationService) {
        self.service = service
        self._settings = Bindable(wrappedValue: service.settings)
    }

    var body: some View {
        SettingsCard("语言") {
            SettingsRow(
                "默认目标语言",
                subtitle: "新翻译默认使用此语言；原文已是该语言时会自动切换中英方向"
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
                "在线翻译授权",
                subtitle: consentSubtitle
            ) {
                Button("重新授权") {
                    settings.resetConsent()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(settings.consentedProviderIDs.isEmpty)
            }
        }

        SettingsCard("引擎优先级") {
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

        SettingsCard("说明") {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    "只有点击翻译时才会把当前文本发送给启用的在线引擎。图片、历史和其他内容不会上传。",
                    systemImage: "lock.shield"
                )

                Label(
                    "Google、Bing、DeepL 的非官方接口没有公开契约，可能限流、失效或违反服务条款；请勿翻译敏感内容。",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.orange)

                Label(
                    "官方 API 凭证保存在 macOS 钥匙串，不写入历史、日志或备份文件。",
                    systemImage: "key"
                )
            }
            .font(.system(size: 10.5, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $configuringProvider) { id in
            TranslationProviderConfigSheet(
                service: service,
                providerID: id
            )
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
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .help("提高优先级")

                Button {
                    settings.moveProvider(id, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == count - 1)
                .help("降低优先级")
            }
            .foregroundStyle(.secondary)

            if descriptor.requiresConfiguration {
                Button(isConfigured ? "修改…" : "配置…") {
                    configuringProvider = id
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("无需配置")
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

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
        guard let credentials = service.credentials.credentials(for: id) else {
            return false
        }
        return credentials.hasValues(for: descriptor)
    }

    private func providerSubtitle(
        _ descriptor: TranslationProviderDescriptor,
        isConfigured: Bool
    ) -> String {
        guard descriptor.requiresConfiguration else {
            return descriptor.subtitle
        }
        return isConfigured ? "已配置 · \(descriptor.subtitle)" : descriptor.subtitle
    }

    private var consentSubtitle: String {
        guard !settings.consentedProviderIDs.isEmpty else {
            return "首次翻译时会询问一次；授权后不会再次打断"
        }

        let names = settings.providerOrder
            .filter { settings.consentedProviderIDs.contains($0) }
            .map(\.descriptor.name)
            .joined(separator: "、")
        return names.isEmpty ? "尚未授权" : "已授权：\(names)"
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
                Text("配置 \(descriptor.name)")
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

            Text("凭证保存在 macOS 钥匙串，不会进入导出备份。测试会产生一次真实翻译请求。")
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
                        Text("测试连接")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isTesting || !credentials.hasValues(for: descriptor))

                if service.credentials.hasCredentials(for: providerID) {
                    Button("清除凭证", role: .destructive) {
                        clearCredentials()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("保存") {
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
                testMessage = "连接成功，翻译接口可用。"
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
