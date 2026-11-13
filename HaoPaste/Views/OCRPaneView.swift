//
//  OCRPaneView.swift
//  HaoPaste
//
//  Editable image OCR result pane with copy, snippet and translation actions.
//

import AppKit
import SwiftUI

struct OCRPaneView: View {
    @Bindable var service: OCRService

    let onCopyText: (String) -> Void
    let onTranslate: (String) -> Void
    let onSaveSnippet: (String) -> Void
    let onClose: () -> Void
    var showsScrim = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false
    @FocusState private var isEditorFocused: Bool

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
            DispatchQueue.main.async {
                isEditorFocused = true
            }
        }
        .onChange(of: service.phase) { _, phase in
            if phase == .success {
                DispatchQueue.main.async {
                    isEditorFocused = true
                }
            }
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            header
            divider
            bodyContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            divider
            footer
        }
        .frame(width: 640, height: 480)
        .glassSurfaceBackground(
            cornerRadius: 14,
            fallback: .popover
        )
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
            Image(systemName: "text.viewfinder")
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
                Text(L("提取文字"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(service.sourceTitle)
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 10)

            if let language = detectedLanguage {
                Text(language.name)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .frame(height: 19)
                    .background {
                        Capsule()
                            .fill(Color.primary.opacity(0.05))
                    }
            }

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
            .help(L("关闭识图（esc）"))
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        if service.phase == .failed {
            errorView
        } else if service.phase == .empty {
            emptyView
        } else {
            VStack(alignment: .leading, spacing: 10) {
                sourceSummary

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.025))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)

                    TextEditor(
                        text: Binding(
                            get: { service.text },
                            set: { service.updateText($0) }
                        )
                    )
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .focused($isEditorFocused)

                    if service.phase == .recognizing {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.regularMaterial)

                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(L("正在识别图片文字…"))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(14)
        }
    }

    private var sourceSummary: some View {
        HStack(spacing: 10) {
            if let imageURL = service.sourceImageURL,
               let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    L("%d 字符 · 可编辑", service.text.count)
                )
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(L("识别结果缓存在本机，可在设置中清除"))
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text(L("未识别到文字"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Text(L("可以尝试更清晰、文字更大的图片，或重新识别。"))
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)

            Button(L("重新识别")) {
                service.recognize(force: true)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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

            Text(L("识别失败"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Text(service.errorMessage ?? L("请稍后重试。"))
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(L("重试")) {
                service.recognize(force: true)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Label(L("本地识别 · 不上传图片"), systemImage: "lock.shield")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            if service.phase == .success {
                secondaryAction(L("重新识别"), systemImage: "arrow.clockwise") {
                    service.recognize(force: true)
                }

                secondaryAction(L("保存片段"), systemImage: "text.badge.plus") {
                    onSaveSnippet(service.text)
                }

                secondaryAction(
                    L("翻译"),
                    systemImage: "character.bubble",
                    isEnabled: !service.text.isEmpty
                ) {
                    onTranslate(service.text)
                }
            } else if service.phase != .recognizing {
                secondaryAction(L("重新识别"), systemImage: "arrow.clockwise") {
                    service.recognize(force: true)
                }
            }

            primaryCopyAction
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }

    private var primaryCopyAction: some View {
        Button {
            onCopyText(service.text)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Text(L("复制文字"))
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
        .disabled(service.text.isEmpty)
        .opacity(service.text.isEmpty ? 0.45 : 1)
        .help(L("复制识别文字并关闭"))
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

    private var detectedLanguage: TranslationLanguage? {
        TranslationLanguage.detect(in: service.text)
    }
}
