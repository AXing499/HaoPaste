//
//  SelectionTranslationCardView.swift
//  HaoPaste
//
//  Compact translation card anchored near the current text selection.
//

import SwiftUI

struct SelectionTranslationCardView: View {
    @Bindable var service: TranslationService

    let onCopyTranslation: () -> Void
    let onCopyBilingual: () -> Void
    let onReplaceOriginal: () -> Void
    let onSaveSnippet: () -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var draftSource = ""

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            content
            divider
            footer
        }
        .frame(width: 400, height: 340)
        .glassSurfaceBackground(
            cornerRadius: 13,
            tint: NSColor.windowBackgroundColor.withAlphaComponent(0.18),
            fallback: .popover
        )
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(
                    Color.primary.opacity(0.10),
                    lineWidth: Theme.hairline
                )
        }
        .scaleEffect(appeared ? 1 : 0.96, anchor: .topLeading)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            draftSource = service.sourceText
            withAnimation(
                reduceMotion || DebugMotion.disablesAnimations
                    ? nil
                    : Theme.spring
            ) {
                appeared = true
            }
        }
        .onChange(of: service.sourceText) { _, newValue in
            draftSource = newValue
        }
        .onChange(of: service.isPresenting) { _, isPresenting in
            if isPresenting {
                draftSource = service.sourceText
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: Theme.hairline)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "character.bubble")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(0.11))
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(L("划词翻译"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(service.sourceTitle)
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Menu {
                ForEach(TranslationLanguage.all) { language in
                    Button(language.name) {
                        selectTargetLanguage(language)
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(service.targetLanguage.name)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(isSourceEmpty)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("关闭"))
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            sourceSection

            switch service.phase {
            case .consentRequired:
                consentContent
            case .translating:
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L("正在翻译…"))
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed:
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.orange)
                    Text(service.errorMessage ?? L("翻译失败"))
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button(L("重试")) {
                            translateDraft()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isSourceEmpty)

                        Button(L("打开翻译设置…"), action: onOpenSettings)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .success:
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(L("译文"))
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)

                        Spacer(minLength: 4)

                        Button {
                            onReplaceOriginal()
                        } label: {
                            Label(
                                L("替换原文"),
                                systemImage: "arrow.turn.up.left"
                            )
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .help(L("将译文粘贴回原应用，替换选中的文字"))
                        .disabled(isDirty)
                    }

                    ScrollView {
                        Text(service.resultText)
                            .font(.system(size: 12.5, design: .rounded))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.never)
                }
                .opacity(isDirty ? 0.55 : 1)

            case .idle:
                Text(L("等待翻译"))
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(L("原文"))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)

                if isDirty {
                    Text(L("未更新"))
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 5)
                        .frame(height: 14)
                        .background {
                            Capsule().fill(Color.orange.opacity(0.10))
                        }
                }

                Spacer(minLength: 4)

                Button {
                    translateDraft()
                } label: {
                    Label(L("翻译"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help(L("翻译（回车）"))
                .disabled(isSourceEmpty || service.phase == .translating)
            }

            TranslationSourceEditor(text: $draftSource) { source in
                translateDraft(source)
            }
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(isDirty ? 0.12 : 0.05),
                        lineWidth: Theme.hairline
                    )
            }
        }
    }

    private var isDirty: Bool {
        draftSource != service.sourceText
    }

    private var isSourceEmpty: Bool {
        draftSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func translateDraft(_ source: String? = nil) {
        guard service.phase != .translating else { return }

        let trimmed = (source ?? draftSource).trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }

        draftSource = trimmed
        service.sourceText = trimmed
        service.detectedSourceID = nil
        service.startTranslation(force: true)
    }

    private func selectTargetLanguage(_ language: TranslationLanguage) {
        let trimmed = draftSource.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !trimmed.isEmpty, trimmed != service.sourceText {
            draftSource = trimmed
            service.sourceText = trimmed
            service.detectedSourceID = nil
        }
        service.setTargetLanguage(language, persist: false)
    }

    private func grantConsentAndTranslateDraft() {
        let trimmed = draftSource.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return }

        if trimmed != service.sourceText {
            draftSource = trimmed
            service.sourceText = trimmed
            service.detectedSourceID = nil
        }
        service.grantConsentAndTranslate()
    }

    private var consentContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)

            Text(L("允许在线翻译？"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))

            Text(
                L(
                    "本次将把当前文本发送给 %@。",
                    service.consentProviderNames
                )
            )
            .font(.system(size: 10, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(L("取消"), action: onClose)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button(L("允许并翻译")) {
                    grantConsentAndTranslateDraft()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.accentColor)
                .disabled(isSourceEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let provider = service.activeProvider {
                Text(provider.name)
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(.tertiary)
            } else if service.phase == .translating {
                Text(L("正在翻译…"))
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 6)

            Button {
                onSaveSnippet()
            } label: {
                Image(systemName: "text.badge.plus")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(L("保存片段"))
            .disabled(service.resultText.isEmpty || isDirty)

            Button(L("复制双语")) {
                onCopyBilingual()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(service.resultText.isEmpty || isDirty)

            Button(L("复制译文")) {
                onCopyTranslation()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color.accentColor)
            .disabled(service.resultText.isEmpty || isDirty)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
    }
}
