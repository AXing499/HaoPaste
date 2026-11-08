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
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            Text("已选择 \(count) 条")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(hint ?? "↵ 合并复制")
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button(action: onClear) {
                Text("取消")
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
            .help("取消多选（esc）")

            Button(action: onMerge) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    Text("合并复制")
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
            .help(canMerge ? "合并复制并关闭（↵）" : (hint ?? "当前选择无法合并"))
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
