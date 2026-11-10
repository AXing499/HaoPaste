//
//  MultiSelectionBar.swift
//  HaoPaste
//
//  Floating action bar shown while multiple history entries are selected.
//

import SwiftUI

struct MultiSelectionBar: View {
    let count: Int
    let hint: String?
    let canMerge: Bool
    let onMerge: () -> Void
    let onRecognizeText: (() -> Void)?
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            Text(L("已选择 %d 条", count))
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(hint ?? L("↵ 合并复制"))
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer(minLength: 12)

            if let onRecognizeText {
                Button(action: onRecognizeText) {
                    HStack(spacing: 4) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        Text(L("识别文字"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .frame(height: 27)
                    .background {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.10))
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.accentColor.opacity(0.20), lineWidth: Theme.hairline)
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(L("批量识别选中图片中的文字"))
            }

            Button(action: onClear) {
                Text(L("取消"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background {
                        Capsule()
                            .fill(Color.primary.opacity(0.05))
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(L("取消多选（esc）"))

            if onRecognizeText == nil {
                Button(action: onMerge) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        Text(L("合并复制"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 11)
                    .frame(height: 27)
                    .background {
                        Capsule()
                            .fill(Color.accentColor.opacity(canMerge ? 1 : 0.35))
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .disabled(!canMerge)
                .help(canMerge ? L("合并复制并关闭（↵）") : (hint ?? L("当前选择无法合并")))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background {
            Capsule(style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: Theme.hairline)
        }
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 5)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
