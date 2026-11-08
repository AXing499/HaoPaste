//
//  ClipboardShelfView.swift
//  HaoPaste
//
//  The horizontal clothesline of recent clipboard entries.
//

import SwiftUI

struct ShelfHitTargetsKey: PreferenceKey {
    static var defaultValue: [ShelfHitTarget] = []

    static func reduce(
        value: inout [ShelfHitTarget],
        nextValue: () -> [ShelfHitTarget]
    ) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func shelfHitArea(_ kind: ShelfHitTarget.Kind) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .allowsHitTesting(false)
                    .preference(
                        key: ShelfHitTargetsKey.self,
                        value: [
                            ShelfHitTarget(
                                kind: kind,
                                rect: proxy.frame(in: .named("ClipboardShelf"))
                            )
                        ]
                    )
            }
        }
    }
}

struct ClipboardShelfView: View {
    @Bindable var manager: ClipboardManager
    @Bindable var settings: AppSettings
    @Bindable var interaction: ShelfInteractionState

    let onHitTargetsChanged: ([ShelfHitTarget]) -> Void
    let onPreviewItem: (ClipboardItem) -> Void

    @State private var filter: ClipboardShelfFilter = .all
    @State private var copiedID: UUID?

    private let cardAngles: [Double] = [-1.1, 0.6, -0.4, 0.9, -0.7, 0.3]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let edge = settings.shelfEdge
            let isSide = edge.isSide
            let filtered = manager
                .filteredItems(query: "", filter: .all)
                .filter { filter.matches($0) }
            let capacity = isSide
                ? ClipboardShelfLayout.sideCapacity(
                    height: height,
                    limit: settings.shelfItemLimit
                )
                : ClipboardShelfLayout.capacity(
                    width: width,
                    limit: settings.shelfItemLimit
                )
            let items = Array(filtered.prefix(capacity))
            let cardWidth = isSide
                ? ClipboardShelfLayout.sideCardWidth(panelWidth: width)
                : ClipboardShelfLayout.cardWidth(
                    width: width,
                    count: max(items.count, 1)
                )
            let topRack = ClipboardShelfLayout.rackSpan(
                width: width,
                count: items.count,
                cardWidth: cardWidth
            )
            let sideRack = ClipboardShelfLayout.sideRackRange(
                height: height,
                count: items.count
            )
            let filterY = height
                - ClipboardShelfLayout.filterBarBottom
                - ClipboardShelfLayout.filterBarHeight / 2

            ZStack(alignment: .top) {
                if isSide {
                    ShelfSideRackView(
                        railX: edge == .left
                            ? ClipboardShelfLayout.sideRailInset
                            : width - ClipboardShelfLayout.sideRailInset,
                        cardCenterX: width / 2,
                        cardWidth: cardWidth,
                        start: sideRack.lowerBound,
                        end: sideRack.upperBound,
                        count: items.count
                    )
                    .animation(Theme.gentleSpring, value: sideRack.lowerBound)
                    .animation(Theme.gentleSpring, value: sideRack.upperBound)
                } else {
                    ShelfRackView(
                        start: topRack.lowerBound,
                        end: topRack.upperBound,
                        sag: ClipboardShelfLayout.sag(
                            span: topRack.upperBound - topRack.lowerBound
                        )
                    )
                    .animation(Theme.gentleSpring, value: topRack.lowerBound)
                    .animation(Theme.gentleSpring, value: topRack.upperBound)
                }

                if items.isEmpty {
                    emptyState
                        .position(
                            x: width / 2,
                            y: isSide ? height / 2 - 40 : 102
                        )
                        .transition(
                            .scale(scale: 0.94, anchor: .center)
                                .combined(with: .opacity)
                        )
                }

                ForEach(Array(items.enumerated()), id: \.element.id) {
                    index,
                    item in
                    let isHovering = interaction.hoveredItemID == item.id
                    let centerX = isSide
                        ? width / 2
                        : ClipboardShelfLayout.centerX(
                            index: index,
                            count: items.count,
                            width: width,
                            cardWidth: cardWidth
                        )
                    let cardTop = isSide
                        ? ClipboardShelfLayout.sideCardTop(index: index)
                        : ClipboardShelfLayout.ropeY(
                            x: centerX,
                            rackStart: topRack.lowerBound,
                            rackEnd: topRack.upperBound
                        ) + ClipboardShelfLayout.cardTopOffset

                    let angle = cardAngles[index % cardAngles.count]
                        * (isSide ? 0.45 : 1)

                    ShelfCardView(
                        item: item,
                        cardWidth: cardWidth,
                        thumbnailURL: manager.thumbnailURL(for: item),
                        imageURL: manager.imageURL(for: item),
                        isHovering: isHovering,
                        isCopied: copiedID == item.id,
                        baseAngle: angle,
                        edge: edge,
                        canDragOut: canDragOut(item),
                        dragProvider: { dragProvider(for: item) },
                        onCopy: { copy(item) },
                        onCopyText: { text in copyText(text, for: item) },
                        onTogglePin: { togglePin(item) },
                        onDelete: { delete(item) },
                        onPreview: { onPreviewItem(item) }
                    )
                    .frame(
                        width: cardWidth,
                        height: ClipboardShelfLayout.cardHeight
                    )
                    .shelfHitArea(.card(item.id))
                    .position(
                        x: centerX,
                        y: cardTop + ClipboardShelfLayout.cardHeight / 2
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.86, anchor: .top)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: -14)),
                            removal: .scale(scale: 0.92, anchor: .top)
                                .combined(with: .opacity)
                        )
                    )
                    .zIndex(isHovering ? 100 : 10 - Double(index))
                }

                ShelfFilterBar(
                    filter: $filter,
                    visibleCount: items.count,
                    totalCount: filtered.count
                )
                .shelfHitArea(.filterBar)
                .position(x: width / 2, y: filterY)
            }
            .coordinateSpace(name: "ClipboardShelf")
            .onPreferenceChange(ShelfHitTargetsKey.self) { targets in
                onHitTargetsChanged(targets)
            }
            .animation(Theme.gentleSpring, value: items.count)
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
        flashCopied(item)
    }

    private func copyText(_ text: String, for item: ClipboardItem) {
        guard manager.copyTextToPasteboard(text) else { return }
        flashCopied(item)
    }

    private func togglePin(_ item: ClipboardItem) {
        withAnimation(Theme.spring) {
            manager.togglePin(item)
        }
    }

    private func delete(_ item: ClipboardItem) {
        withAnimation(Theme.gentleSpring) {
            manager.delete(item)
        }
    }

    private func flashCopied(_ item: ClipboardItem) {
        copiedID = item.id
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            if copiedID == item.id {
                copiedID = nil
            }
        }
    }

    private func canDragOut(_ item: ClipboardItem) -> Bool {
        switch item.type {
        case .image:
            return manager.imageURL(for: item) != nil
        case .file:
            return item.availableFileURLs.count == 1
        case .text, .code, .url, .colorHex:
            return true
        }
    }

    private func dragProvider(for item: ClipboardItem) -> NSItemProvider {
        ItemDragProvider.make(
            for: item,
            imageURL: manager.imageURL(for: item),
            richText: manager.richText(for: item)
        )
    }
}

// MARK: - Rack

/// A wall-mounted rail with a sagging line. The endpoints and sag are
/// animatable so the rack breathes with the filter result instead of snapping.
private struct ShelfRackView: View, Animatable {
    var start: CGFloat
    var end: CGFloat
    var sag: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        CGFloat
    > {
        get {
            AnimatablePair(AnimatablePair(start, end), sag)
        }
        set {
            start = newValue.first.first
            end = newValue.first.second
            sag = newValue.second
        }
    }

    var body: some View {
        Canvas { context, _ in
            let railY = ClipboardShelfLayout.railTop
            let lineY = ClipboardShelfLayout.lineTop
            let plateWidth: CGFloat = 7
            let plateHeight: CGFloat = 20
            let middle = (start + end) / 2

            for x in [start, end] {
                let plate = CGRect(
                    x: x - plateWidth / 2,
                    y: 0,
                    width: plateWidth,
                    height: plateHeight
                )
                context.fill(
                    Path(roundedRect: plate, cornerRadius: 3.5),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.primary.opacity(0.20),
                            Color.primary.opacity(0.08)
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: plateHeight)
                    )
                )

                let screw = CGRect(x: x - 1.4, y: 5, width: 2.8, height: 2.8)
                context.fill(
                    Path(ellipseIn: screw),
                    with: .color(Color.primary.opacity(0.30))
                )
            }

            var rail = Path()
            rail.move(to: CGPoint(x: start, y: railY))
            rail.addLine(to: CGPoint(x: end, y: railY))
            context.stroke(
                rail,
                with: .color(Color.primary.opacity(0.20)),
                lineWidth: 1.8
            )

            var railHighlight = Path()
            railHighlight.move(to: CGPoint(x: start, y: railY - 0.8))
            railHighlight.addLine(to: CGPoint(x: end, y: railY - 0.8))
            context.stroke(
                railHighlight,
                with: .color(Color.white.opacity(0.20)),
                lineWidth: 0.7
            )

            var rope = Path()
            rope.move(to: CGPoint(x: start, y: lineY))
            rope.addQuadCurve(
                to: CGPoint(x: end, y: lineY),
                control: CGPoint(x: middle, y: lineY + sag * 2)
            )

            context.stroke(
                rope.offsetBy(dx: 0, dy: 0.8),
                with: .color(Color.black.opacity(0.10)),
                lineWidth: 1.4
            )
            context.stroke(
                rope,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.primary.opacity(0.38),
                        Color.primary.opacity(0.26),
                        Color.primary.opacity(0.38)
                    ]),
                    startPoint: CGPoint(x: start, y: lineY),
                    endPoint: CGPoint(x: end, y: lineY)
                ),
                lineWidth: 1.2
            )

            for x in [start, end] {
                let knot = CGRect(
                    x: x - 2.4,
                    y: lineY - 2.4,
                    width: 4.8,
                    height: 4.8
                )
                context.fill(
                    Path(ellipseIn: knot),
                    with: .color(Color.primary.opacity(0.26))
                )
            }
        }
        .frame(height: 64, alignment: .top)
        .allowsHitTesting(false)
    }
}

/// A vertical peg rail for left / right edge mode. Cards hang from arms
/// clipped to their outer top edge; the rail stays visible near the screen edge.
private struct ShelfSideRackView: View, Animatable {
    var railX: CGFloat
    var cardCenterX: CGFloat
    var cardWidth: CGFloat
    var start: CGFloat
    var end: CGFloat
    var count: Int

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(start, end),
                AnimatablePair(railX, cardCenterX)
            )
        }
        set {
            start = newValue.first.first
            end = newValue.first.second
            railX = newValue.second.first
            cardCenterX = newValue.second.second
        }
    }

    var body: some View {
        Canvas { context, _ in
            let plateWidth: CGFloat = 20
            let plateHeight: CGFloat = 7
            let isLeft = railX < cardCenterX
            let clipCenterX = isLeft
                ? cardCenterX - cardWidth / 2 + 6.5
                : cardCenterX + cardWidth / 2 - 6.5

            for y in [start, end] {
                let plate = CGRect(
                    x: railX - plateWidth / 2,
                    y: y - plateHeight / 2,
                    width: plateWidth,
                    height: plateHeight
                )
                context.fill(
                    Path(roundedRect: plate, cornerRadius: 3.5),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.primary.opacity(0.20),
                            Color.primary.opacity(0.08)
                        ]),
                        startPoint: CGPoint(x: 0, y: plate.minY),
                        endPoint: CGPoint(x: 0, y: plate.maxY)
                    )
                )

                let screw = CGRect(
                    x: railX - 1.4,
                    y: y - 1.4,
                    width: 2.8,
                    height: 2.8
                )
                context.fill(
                    Path(ellipseIn: screw),
                    with: .color(Color.primary.opacity(0.30))
                )
            }

            var rail = Path()
            rail.move(to: CGPoint(x: railX, y: start))
            rail.addLine(to: CGPoint(x: railX, y: end))
            context.stroke(
                rail,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.primary.opacity(0.38),
                        Color.primary.opacity(0.26),
                        Color.primary.opacity(0.38)
                    ]),
                    startPoint: CGPoint(x: railX, y: start),
                    endPoint: CGPoint(x: railX, y: end)
                ),
                lineWidth: 1.4
            )

            var highlight = Path()
            highlight.move(to: CGPoint(x: railX - 0.7, y: start))
            highlight.addLine(to: CGPoint(x: railX - 0.7, y: end))
            context.stroke(
                highlight,
                with: .color(Color.white.opacity(0.16)),
                lineWidth: 0.6
            )

            for index in 0..<max(count, 0) {
                let y = ClipboardShelfLayout.sideCardTop(index: index)
                    + ClipboardShelfLayout.clipHeight / 2
                var arm = Path()
                arm.move(to: CGPoint(x: railX, y: y))
                arm.addLine(to: CGPoint(x: clipCenterX, y: y))
                context.stroke(
                    arm,
                    with: .color(Color.primary.opacity(0.24)),
                    lineWidth: 1.0
                )

                let peg = CGRect(
                    x: railX - 1.6,
                    y: y - 1.6,
                    width: 3.2,
                    height: 3.2
                )
                context.fill(
                    Path(ellipseIn: peg),
                    with: .color(Color.primary.opacity(0.30))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - Filter bar

private struct ShelfFilterBar: View {
    @Binding var filter: ClipboardShelfFilter
    let visibleCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ClipboardShelfFilter.allCases) { option in
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
                            .shadow(
                                color: filter == option
                                    ? Color.accentColor.opacity(0.24)
                                    : .clear,
                                radius: 4,
                                x: 0,
                                y: 1
                            )
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        select(option)
                    }
                    .accessibilityElement()
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(filter == option ? .isSelected : [])
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        select(option)
                    }
            }

            Text(countLabel)
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
                .animation(Theme.quickSpring, value: countLabel)
                .padding(.leading, 4)
                .padding(.trailing, 2)
        }
        .padding(.horizontal, 5)
        .frame(height: ClipboardShelfLayout.filterBarHeight)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .allowsHitTesting(false)
        }
        .overlay {
            Capsule()
                .strokeBorder(Theme.hairlineColor, lineWidth: Theme.hairline)
                .allowsHitTesting(false)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
        .animation(Theme.gentleSpring, value: countLabel)
    }

    private func select(_ option: ClipboardShelfFilter) {
        guard filter != option else { return }
        withAnimation(Theme.gentleSpring) {
            filter = option
        }
    }

    private var countLabel: String {
        if totalCount > visibleCount {
            return "\(visibleCount)/\(totalCount) 条"
        }
        return "\(totalCount) 条"
    }
}
