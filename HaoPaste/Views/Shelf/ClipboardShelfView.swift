//
//  ClipboardShelfView.swift
//  HaoPaste
//
//  The horizontal "clothesline" of recent clipboard entries.
//

import SwiftUI

struct ShelfHitRectsKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func shelfHitArea() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ShelfHitRectsKey.self,
                    value: [proxy.frame(in: .named("ClipboardShelf"))]
                )
            }
        }
    }
}

struct ClipboardShelfView: View {
    @Bindable var manager: ClipboardManager
    @Bindable var settings: AppSettings

    let onHitRectsChanged: ([CGRect]) -> Void

    @State private var filter: ClipboardShelfFilter = .all
    @State private var copiedID: UUID?

    private let cardAngles: [Double] = [-1.2, 0.7, -0.5, 1.0, -0.8, 0.4]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let filtered = manager
                .filteredItems(query: "", filter: .all)
                .filter { filter.matches($0) }
            let capacity = ClipboardShelfLayout.capacity(
                width: width,
                limit: settings.shelfItemLimit
            )
            let items = Array(filtered.prefix(capacity))
            let cardWidth = ClipboardShelfLayout.cardWidth(
                width: width,
                count: max(items.count, 1)
            )

            ZStack(alignment: .top) {
                ShelfRopeView(width: width)

                if items.isEmpty {
                    emptyState
                        .position(x: width / 2, y: 92)
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let centerX = ClipboardShelfLayout.centerX(
                        index: index,
                        count: items.count,
                        width: width,
                        cardWidth: cardWidth
                    )
                    let ropeY = ClipboardShelfLayout.ropeY(
                        x: centerX,
                        width: width
                    )

                    ShelfCardView(
                        item: item,
                        cardWidth: cardWidth,
                        thumbnailURL: manager.thumbnailURL(for: item),
                        isCopied: copiedID == item.id,
                        baseAngle: cardAngles[index % cardAngles.count]
                    ) {
                        copy(item)
                    }
                    .frame(
                        width: cardWidth,
                        height: ClipboardShelfLayout.cardHeight
                    )
                    .shelfHitArea()
                    .position(
                        x: centerX,
                        y: ropeY + ClipboardShelfLayout.cardHeight / 2
                    )
                    .zIndex(10 - Double(index))
                }

                ShelfFilterBar(
                    filter: $filter,
                    visibleCount: items.count,
                    totalCount: filtered.count
                )
                .shelfHitArea()
                .padding(.bottom, ClipboardShelfLayout.filterBarBottom)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottom
                )
            }
            .coordinateSpace(name: "ClipboardShelf")
            .onPreferenceChange(ShelfHitRectsKey.self) { rects in
                onHitRectsChanged(rects)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: filter.symbolName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
            Text("暂无\(filter.title)记录")
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background {
            Capsule()
                .fill(.regularMaterial)
        }
        .overlay {
            Capsule()
                .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
        }
    }

    private func copy(_ item: ClipboardItem) {
        guard manager.copyToPasteboard(item) else { return }

        copiedID = item.id
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            if copiedID == item.id {
                copiedID = nil
            }
        }
    }
}

private struct ShelfRopeView: View {
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            let top = ClipboardShelfLayout.lineTop
            let sag = ClipboardShelfLayout.sag(width: size.width)

            var path = Path()
            path.move(to: CGPoint(x: 0, y: top))
            path.addQuadCurve(
                to: CGPoint(x: size.width, y: top),
                control: CGPoint(
                    x: size.width / 2,
                    y: top + sag * 2
                )
            )

            context.stroke(
                path,
                with: .color(Color.primary.opacity(0.17)),
                lineWidth: 0.7
            )

            // Small end knots.
            for x in [CGFloat(2), size.width - 2] {
                let rect = CGRect(x: x - 2.5, y: top - 2.5, width: 5, height: 5)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.primary.opacity(0.22))
                )
            }
        }
        .frame(width: width, height: ClipboardShelfLayout.lineTop + 20)
        .allowsHitTesting(false)
    }
}

private struct ShelfFilterBar: View {
    @Binding var filter: ClipboardShelfFilter
    let visibleCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ClipboardShelfFilter.allCases) { option in
                Button {
                    withAnimation(Theme.quickSpring) {
                        filter = option
                    }
                } label: {
                    Text(option.title)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            filter == option
                                ? Color.white
                                : Color.secondary
                        )
                        .padding(.horizontal, 9)
                        .frame(height: 22)
                        .background {
                            Capsule()
                                .fill(
                                    filter == option
                                        ? Color.accentColor
                                        : Color.clear
                                )
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            Text(countLabel)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .padding(.leading, 4)
                .padding(.trailing, 2)
        }
        .padding(.horizontal, 5)
        .frame(height: ClipboardShelfLayout.filterBarHeight)
        .background {
            Capsule()
                .fill(.regularMaterial)
        }
        .overlay {
            Capsule()
                .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    private var countLabel: String {
        if totalCount > visibleCount {
            return "\(visibleCount)/\(totalCount) 条"
        }
        return "\(totalCount) 条"
    }
}
