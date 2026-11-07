//
//  FilterTabsView.swift
//  HaoPaste
//
//  Smooth, sliding pill tabs for the clipboard categories.
//

import SwiftUI

struct FilterTabsView: View {
    @Binding var selection: ClipboardFilter
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ClipboardFilter.allCases) { filter in
                FilterPill(
                    filter: filter,
                    isSelected: selection == filter,
                    namespace: selectionNamespace
                ) {
                    guard selection != filter else { return }
                    withAnimation(Theme.spring) {
                        selection = filter
                    }
                }
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.035))
        }
        .overlay {
            Capsule()
                .strokeBorder(Theme.subtleBorderColor, lineWidth: Theme.hairline)
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("剪切板分类")
    }
}

private struct FilterPill: View {
    let filter: ClipboardFilter
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(filter.title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background {
                    background
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(reduceMotion ? nil : Theme.spring, value: isHovering)
        .animation(reduceMotion ? nil : Theme.spring, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            Capsule()
                .fill(Color.accentColor.opacity(0.13))
                .matchedGeometryEffect(id: "filterSelection", in: namespace)
                .overlay {
                    Capsule()
                        .strokeBorder(Color.accentColor.opacity(0.16), lineWidth: Theme.hairline)
                }
        } else if isHovering {
            Capsule()
                .fill(Color.primary.opacity(0.05))
        }
    }

    private var foregroundColor: Color {
        if isSelected {
            return .accentColor
        }
        return isHovering ? .primary : .secondary
    }
}
