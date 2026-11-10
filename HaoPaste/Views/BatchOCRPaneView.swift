//
//  BatchOCRPaneView.swift
//  HaoPaste
//
//  Batch image OCR results with per-image copy/translate and merged output.
//

import AppKit
import SwiftUI

struct BatchOCRPaneView: View {
    @Bindable var service: OCRService

    let onCopyAll: (String) -> Void
    let onCopyEntry: (String) -> Void
    let onTranslateEntry: (String, String) -> Void
    let onSaveSnippet: (String) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .contentShape(Rectangle())
                .onTapGesture {
                    onClose()
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

    private var card: some View {
        VStack(spacing: 0) {
            header
            divider
            entryList
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
        .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 1)
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
                Text(L("批量提取文字"))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(statusText)
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            if service.batchProgressTotal > 0,
               service.batchProgressCurrent < service.batchProgressTotal {
                Text("\(service.batchProgressCurrent)/\(service.batchProgressTotal)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
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

    private var statusText: String {
        if let language = TranslationLanguage.detect(
            in: service.batchEntries.map(\.text).joined(separator: "\n")
        ) {
            return L(
                "%d 张图片 · %@",
                service.batchEntries.count,
                language.name
            )
        }
        return L("%d 张图片", service.batchEntries.count)
    }

    private var entryList: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 8) {
                ForEach(service.batchEntries) { entry in
                    batchRow(entry)
                }
            }
            .padding(14)
        }
        .scrollIndicators(.never)
    }

    private func batchRow(_ entry: OCRService.BatchEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let image = NSImage(contentsOf: entry.imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
                    }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.title)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .lineLimit(1)

                    badge(for: entry)
                    Spacer(minLength: 6)
                }

                switch entry.phase {
                case .recognizing:
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L("识别中…"))
                            .font(.system(size: 10.5, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                case .failed:
                    Text(entry.errorMessage ?? L("识别失败"))
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                case .empty:
                    Text(L("未识别到文字"))
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.tertiary)
                case .idle, .success:
                    Text(entry.text.isEmpty ? L("等待识别") : entry.text)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 4) {
                Button(L("编辑")) {
                    service.openBatchEntry(id: entry.id)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

                Button(L("复制")) {
                    onCopyEntry(entry.text)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .disabled(entry.text.isEmpty)

                Button(L("翻译")) {
                    onTranslateEntry(entry.text, entry.title)
                }
                .buttonStyle(.plain)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .disabled(entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.025))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
        }
    }

    private func badge(for entry: OCRService.BatchEntry) -> some View {
        Group {
            switch entry.phase {
            case .success:
                Text(L("%d 字符", entry.text.count))
            case .recognizing:
                Text(L("识别中"))
            case .empty:
                Text(L("无文字"))
            case .failed:
                Text(L("失败"))
            case .idle:
                Text(L("等待"))
            }
        }
        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
        .foregroundStyle(
            entry.phase == .failed
                ? Color.orange
                : (entry.phase == .success ? Color.secondary : Color.secondary.opacity(0.55))
        )
        .padding(.horizontal, 5)
        .frame(height: 15)
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.045))
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Label(L("本地识别 · 不上传图片"), systemImage: "lock.shield")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            secondaryAction(L("重新识别"), systemImage: "arrow.clockwise") {
                service.recognizeBatch(force: true)
            }
            .disabled(
                service.batchEntries.contains { $0.phase == .recognizing }
            )

            secondaryAction(
                L("保存为片段"),
                systemImage: "text.badge.plus",
                isEnabled: !mergedText.isEmpty
            ) {
                onSaveSnippet(mergedText)
            }

            Button {
                onCopyAll(mergedText)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                    Text(L("复制全部"))
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
            .disabled(mergedText.isEmpty)
            .opacity(mergedText.isEmpty ? 0.45 : 1)
            .help(L("复制全部识别文字并关闭"))
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
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

    private var mergedText: String {
        service.batchEntries.compactMap { entry in
            let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return "\(entry.title)\n\(text)"
        }
        .joined(separator: "\n\n---\n\n")
    }
}
