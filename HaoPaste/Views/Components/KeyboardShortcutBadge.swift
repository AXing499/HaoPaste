//
//  KeyboardShortcutBadge.swift
//  HaoPaste
//
//  Small keycaps used in rows and the footer.
//

import SwiftUI

struct KeyboardShortcutBadge: View {
    let text: String
    var emphasized = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(emphasized ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 24, minHeight: 19)
            .background {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .strokeBorder(
                        emphasized ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08),
                        lineWidth: Theme.hairline
                    )
            }
            .accessibilityHidden(true)
    }
}

struct FooterShortcutHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            KeyboardShortcutBadge(text: keys)
            Text(label)
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }
}

struct RoundIconButton: View {
    let symbolName: String
    let help: String
    var bounceValue: Bool? = nil
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isHovering ? Color.primary : Color.secondary)
                .frame(width: 22, height: 22)
                .symbolEffect(
                    .bounce,
                    options: .nonRepeating,
                    value: bounceValue ?? false
                )
                .background {
                    RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
                }
                .contentShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .pointingHandCursor()
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        .help(help)
    }
}
