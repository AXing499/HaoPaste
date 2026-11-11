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
    let onSaveSnippet: () -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            header
            divider
            content
            divider
            footer
        }
        .frame(width: 400, height: 340)
        .background(.regularMaterial)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: Theme.hairline)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
        .scaleEffect(appeared ? 1 : 0.96, anchor: .topLeading)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(
                reduceMotion || DebugMotion.disablesAnimations
                    ? nil
                    : Theme.spring
            ) {
                appeared = true
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
                        service.setTargetLanguage(language, persist: false)
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
            Text(service.sourceText)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                }

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
                            service.retry()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(L("打开翻译设置…"), action: onOpenSettings)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .success:
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("译文"))
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)

                    ScrollView {
                        Text(service.resultText)
                            .font(.system(size: 12.5, design: .rounded))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.never)
                }

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
                    service.grantConsentAndTranslate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.accentColor)
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
            .disabled(service.resultText.isEmpty)

            Button(L("复制双语")) {
                onCopyBilingual()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(service.resultText.isEmpty)

            Button(L("复制译文")) {
                onCopyTranslation()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(Color.accentColor)
            .disabled(service.resultText.isEmpty)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
    }
}
