//
//  TranslationPaneView.swift
//  HaoPaste
//
//  In-panel translation workspace with consent, language and engine controls.
//

import SwiftUI

struct TranslationPaneView: View {
    @Bindable var service: TranslationService

    let onCopyTranslation: (String) -> Void
    let onCopyBilingual: (String) -> Void
    let onSaveSnippet: (String) -> Void
    let onClose: () -> Void
    var showsScrim = true
    var onOpenSettings: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    private let displayLimit = 20_000

    var body: some View {
        ZStack {
            if showsScrim {
                Color.black.opacity(0.30)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onClose()
                    }
            }

            card
                .scaleEffect(isPresented ? 1 : 0.96)
                .opacity(isPresented ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : Theme.spring) {
                isPresented = true
            }
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            header

            divider

            languageBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            divider

            bodyContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            divider

            footer
        }
        .frame(width: 640, height: 480)
        .background(.regularMaterial)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: Theme.hairline)
        }
        .shadow(
            color: showsScrim ? Color.black.opacity(0.28) : .clear,
            radius: showsScrim ? 24 : 0,
            x: 0,
            y: showsScrim ? 10 : 0
        )
        .shadow(
            color: showsScrim ? Color.black.opacity(0.10) : .clear,
            radius: showsScrim ? 4 : 0,
            x: 0,
            y: showsScrim ? 1 : 0
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: Theme.hairline)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.bubble")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.11))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: Theme.hairline)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(L("翻译"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(service.sourceTitle)
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 10)

            Text(L("%d 字符", service.sourceText.count))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background {
                        Circle()
                            .fill(Color.primary.opacity(0.055))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(L("关闭翻译（esc）"))
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    // MARK: - Language / engine controls

    private var languageBar: some View {
        HStack(spacing: 8) {
            chip(
                text: service.detectedLanguage?.name ?? L("自动检测"),
                systemImage: "waveform"
            )

            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)

            Menu {
                ForEach(TranslationLanguage.all) { language in
                    Button(language.name) {
                        service.setTargetLanguage(language)
                    }
                }
            } label: {
                menuChip(
                    text: service.targetLanguage.name,
                    systemImage: "globe"
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Spacer(minLength: 8)

            Menu {
                Button(L("自动选择")) {
                    service.setPreferredProvider(nil)
                }

                if !service.availableProviders.isEmpty {
                    Divider()
                    ForEach(service.availableProviders) { provider in
                        Button("\(provider.name) · \(provider.kind.label)") {
                            service.setPreferredProvider(provider.id)
                        }
                    }
                }
            } label: {
                menuChip(
                    text: engineLabel,
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(L("选择翻译引擎"))
        }
    }

    private var engineLabel: String {
        if let active = service.activeProvider {
            return active.name
        }
        if let preferred = service.preferredProviderID {
            return preferred.descriptor.name
        }
        return L("自动选择")
    }

    private func chip(text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            Text(text)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.045))
        }
        .overlay {
            Capsule()
                .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
        }
    }

    private func menuChip(text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            Text(text)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
            Image(systemName: "chevron.down")
                .font(.system(size: 7.5, weight: .bold, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.055))
        }
        .overlay {
            Capsule()
                .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        switch service.phase {
        case .consentRequired:
            consentView
        case .failed:
            errorView
        default:
            translationView
        }
    }

    private var translationView: some View {
        VStack(alignment: .leading, spacing: 10) {
            textSection(
                title: L("原文"),
                text: displayText(service.sourceText),
                isOriginal: true
            )

            HStack(spacing: 6) {
                Text(L("译文"))
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                if let provider = service.activeProvider {
                    providerBadge(provider)
                }

                Spacer()

                if service.progressTotal > 1 {
                    Text("\(service.progressCurrent)/\(service.progressTotal)")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.025))
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)

                if service.phase == .translating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L("正在翻译…"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if service.resultText.isEmpty {
                    Text(L("等待翻译"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(14)
                } else {
                    ScrollView(.vertical) {
                        Text(displayText(service.resultText))
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .scrollIndicators(.never)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(14)
    }

    private func textSection(
        title: String,
        text: String,
        isOriginal: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            ScrollView(.vertical) {
                Text(text)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .scrollIndicators(.never)
            .frame(maxHeight: isOriginal ? 94 : .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.025))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
            }
        }
    }

    private func providerBadge(_ provider: TranslationProviderDescriptor) -> some View {
        Text(provider.kind.label)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(
                provider.kind == .unofficial
                    ? Color.orange
                    : Color.secondary
            )
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background {
                Capsule()
                    .fill(
                        provider.kind == .unofficial
                            ? Color.orange.opacity(0.11)
                            : Color.primary.opacity(0.05)
                    )
            }
    }

    private var consentView: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            Text(L("允许在线翻译？"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Text(
                L(
                    "本次将把当前文本发送给 %@。",
                    service.consentProviderNames
                )
            )
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if service.consentProviders.contains(where: {
                $0.descriptor.kind == .unofficial
            }) {
                Label(
                    L("其中包含非官方接口，可能违反服务条款或随时失效，请勿翻译敏感内容。"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Button(L("取消")) {
                    onClose()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(L("允许并翻译")) {
                    service.grantConsentAndTranslate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.accentColor)
            }
            .padding(.top, 2)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)

            Text(L("翻译失败"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Text(service.errorMessage ?? L("请稍后重试。"))
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(L("重试")) {
                service.retry()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if service.availableProviderIDs.isEmpty {
                Button(L("打开翻译设置…")) {
                    if let onOpenSettings {
                        onOpenSettings()
                    } else {
                        NotificationCenter.default.post(
                            name: .haopasteOpenTranslationSettings,
                            object: nil
                        )
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 11, design: .rounded))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            if let provider = service.activeProvider {
                Label(
                    "\(provider.name) · \(provider.kind.label)",
                    systemImage: provider.kind == .unofficial
                        ? "exclamationmark.triangle"
                        : "checkmark.shield"
                )
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(
                    provider.kind == .unofficial
                        ? Color.orange
                        : Color.secondary
                )
            } else if let detected = service.detectedLanguage {
                Text(L("检测到%@", detected.name))
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text(L("在线翻译"))
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            if service.phase == .success || (service.phase == .failed && !service.resultText.isEmpty) {
                secondaryAction(
                    L("保存片段"),
                    systemImage: "text.badge.plus"
                ) {
                    onSaveSnippet(service.resultText)
                }
            }

            secondaryAction(
                L("复制双语"),
                systemImage: "doc.on.doc",
                isEnabled: !service.resultText.isEmpty
            ) {
                onCopyBilingual(bilingualText)
            }

            primaryCopyAction
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    private var primaryCopyAction: some View {
        Button {
            onCopyTranslation(service.resultText)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Text(L("复制译文"))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .frame(height: 27)
            .background {
                Capsule()
                    .fill(Color.accentColor)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(service.resultText.isEmpty)
        .opacity(service.resultText.isEmpty ? 0.45 : 1)
        .help(L("复制译文并关闭（↵）"))
    }

    private func secondaryAction(
        _ title: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .padding(.horizontal, 9)
            .frame(height: 27)
            .background {
                Capsule()
                    .fill(Color.primary.opacity(isEnabled ? 0.06 : 0.03))
            }
            .overlay {
                Capsule()
                    .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!isEnabled)
        .help(title)
    }

    // MARK: - Helpers

    private var bilingualText: String {
        L(
            "原文：\n%@\n\n译文：\n%@",
            service.sourceText,
            service.resultText
        )
    }

    private func displayText(_ text: String) -> String {
        guard text.count > displayLimit else { return text }
        return String(text.prefix(displayLimit)) + "\n\n…"
    }
}

extension Notification.Name {
    static let haopasteOpenTranslationSettings = Notification.Name(
        "HaoPaste.OpenTranslationSettings"
    )
}
