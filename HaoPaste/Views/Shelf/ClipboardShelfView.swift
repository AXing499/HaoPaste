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

struct ShelfScrollMetricsKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FallingCardModifier: ViewModifier, Animatable {
    var progress: CGFloat
    let drift: CGFloat
    let rotation: Double

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .offset(x: drift * progress, y: 150 * progress)
            .rotationEffect(.degrees(rotation * Double(progress)), anchor: .top)
            .opacity(1 - progress)
    }
}

private struct ShelfVisibleItem: Identifiable {
    let index: Int
    let item: ClipboardItem

    var id: UUID { item.id }
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
    let onTranslateItem: (ClipboardItem) -> Void
    let onMaxScrollOffsetChanged: (CGFloat) -> Void

    @State private var filter: ClipboardShelfFilter = .all
    @State private var copiedID: UUID?
    @State private var scrollHintVisible = false
    @State private var scrollHintToken = UUID()

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let edge = settings.shelfEdge
            let isSide = edge.isSide
            let filtered = manager
                .filteredItems(query: "", filter: .all)
                .filter { filter.matches($0) }
            let limit = settings.shelfItemLimit
            let loadedCount = limit < 0
                ? filtered.count
                : min(filtered.count, limit)
            let loadedItems = Array(filtered.prefix(loadedCount))
            let count = loadedItems.count
            let cardWidth = isSide
                ? ClipboardShelfLayout.sideCardWidth(panelWidth: width)
                : ClipboardShelfLayout.cardWidth(
                    width: width,
                    count: max(count, 1)
                )
            let cardHeights = loadedItems.map {
                ClipboardShelfLayout.cardHeight(
                    for: $0,
                    cardWidth: cardWidth,
                    edge: edge
                )
            }
            let sideTops = ClipboardShelfLayout.sideCardTops(
                cardHeights: cardHeights
            )
            let sideContentBottom = sideTops.last.map {
                $0 + (cardHeights.last ?? ClipboardShelfLayout.cardHeight)
            } ?? 0
            let sideContentHeight = ClipboardShelfLayout.sideContentHeight(
                cardHeights: cardHeights
            )
            let topMaxOffset = isSide
                ? 0
                : ClipboardShelfLayout.topMaxScrollOffset(
                    width: width,
                    count: count,
                    cardWidth: cardWidth
                )
            let sideMaxOffset = isSide
                ? ClipboardShelfLayout.sideMaxScrollOffset(
                    height: height,
                    cardHeights: cardHeights
                )
                : 0
            let maxOffset = isSide ? sideMaxOffset : topMaxOffset
            let scrollable = maxOffset > 0.5
            let scrollOffset = min(
                max(interaction.scrollOffset, 0),
                maxOffset
            )
            let topRack = ClipboardShelfLayout.topRackSpan(
                width: width,
                count: count,
                cardWidth: cardWidth,
                scrollable: scrollable
            )
            let sideRack = ClipboardShelfLayout.sideRackRange(
                height: height,
                contentBottom: sideContentBottom,
                scrollable: scrollable
            )
            let totalCardWidth = ClipboardShelfLayout.totalWidth(
                count: count,
                cardWidth: cardWidth
            )
            let topStartX = scrollable
                ? ClipboardShelfLayout.sidePadding
                : (width - totalCardWidth) / 2
            let topStep = cardWidth + ClipboardShelfLayout.spacing
            let visibleBottom = ClipboardShelfLayout.sideVisibleBottom(
                height: height
            )
            let visibleRange = isSide
                ? ClipboardShelfLayout.sideVisibleRange(
                    cardTops: sideTops,
                    cardHeights: cardHeights,
                    offset: scrollOffset,
                    height: height,
                    buffer: 220
                )
                : ClipboardShelfLayout.topVisibleRange(
                    width: width,
                    count: count,
                    cardWidth: cardWidth,
                    offset: scrollOffset,
                    scrollable: scrollable,
                    buffer: 240
                )
            let visibleItems = visibleRange.map {
                ShelfVisibleItem(index: $0, item: loadedItems[$0])
            }
            let filterY = height
                - ClipboardShelfLayout.filterBarBottom
                - ClipboardShelfLayout.filterBarHeight / 2
            let maskHeight = max(
                0,
                height
                    - ClipboardShelfLayout.filterBarBottom
                    - ClipboardShelfLayout.filterBarHeight
            )
            let railX = edge == .left
                ? ClipboardShelfLayout.sideRailInset
                : width - ClipboardShelfLayout.sideRailInset
            let clipCenterX = edge == .left
                ? width / 2
                    - cardWidth / 2
                    + ClipboardShelfLayout.sideClipInset
                : width / 2
                    + cardWidth / 2
                    - ClipboardShelfLayout.sideClipInset

            ZStack(alignment: .top) {
                ZStack(alignment: .top) {
                    if isSide {
                        ShelfSideRackView(
                            railX: railX,
                            start: sideRack.lowerBound,
                            end: sideRack.upperBound
                        )
                        .animation(
                            Theme.gentleSpring,
                            value: sideRack.lowerBound
                        )
                        .animation(
                            Theme.gentleSpring,
                            value: sideRack.upperBound
                        )

                        ForEach(visibleItems, id: \.item.id) { entry in
                            ShelfSideArmView(
                                railX: railX,
                                clipX: clipCenterX
                            )
                            .position(
                                x: (railX + clipCenterX) / 2,
                                y: sideTops[entry.index] - scrollOffset
                                    + ClipboardShelfLayout.clipLoopY
                            )
                            .allowsHitTesting(false)
                        }
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

                if count == 0 {
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

                ForEach(visibleItems, id: \.item.id) { entry in
                    let item = entry.item
                    let index = entry.index
                    let isHovering = interaction.hoveredItemID == item.id
                    let cardHeight = cardHeights[index]
                    let centerX = isSide
                        ? width / 2
                        : topStartX
                            + CGFloat(index) * topStep
                            + cardWidth / 2
                            - scrollOffset
                    let cardTop = isSide
                        ? sideTops[index] - scrollOffset
                        : ClipboardShelfLayout.ropeY(
                            x: centerX,
                            rackStart: topRack.lowerBound,
                            rackEnd: topRack.upperBound
                        ) + ClipboardShelfLayout.cardTopOffset
                    let fallDirection: CGFloat = index.isMultiple(of: 2) ? -1 : 1
                    ShelfCardView(
                        item: item,
                        cardWidth: cardWidth,
                        thumbnailURL: manager.thumbnailURL(for: item),
                        imageURL: manager.imageURL(for: item),
                        isHovering: isHovering,
                        isCopied: copiedID == item.id,
                        cardHeight: cardHeight,
                        edge: edge,
                        canDragOut: canDragOut(item),
                        dragProvider: { dragProvider(for: item) },
                        onCopy: { copy(item) },
                        onCopyText: { text in copyText(text, for: item) },
                        onTogglePin: { togglePin(item) },
                        onDelete: { delete(item) },
                        onPreview: { onPreviewItem(item) },
                        onTranslate: { onTranslateItem(item) }
                    )
                    .id(item.id)
                    .frame(
                        width: cardWidth,
                        height: cardHeight
                    )
                    .shelfHitArea(.card(item.id))
                    .position(
                        x: centerX,
                        y: cardTop + cardHeight / 2
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.86, anchor: .top)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: -14)),
                            removal: .modifier(
                                active: FallingCardModifier(
                                    progress: 1,
                                    drift: 16 * fallDirection,
                                    rotation: 9 * Double(fallDirection)
                                ),
                                identity: FallingCardModifier(
                                    progress: 0,
                                    drift: 16 * fallDirection,
                                    rotation: 9 * Double(fallDirection)
                                )
                            )
                        )
                    )
                    .zIndex(isHovering ? 100 : 10 - Double(index))
                }

                    if scrollHintVisible && maxOffset > 0.5 {
                        ShelfScrollIndicator(
                            edge: edge,
                            offset: scrollOffset,
                            maxOffset: maxOffset,
                            contentLength: isSide
                                ? sideContentHeight
                                : totalCardWidth,
                            viewportLength: isSide ? visibleBottom : width,
                            panelWidth: width,
                            panelHeight: height
                        )
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(200)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .mask {
                    VStack(spacing: 0) {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.94),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: maskHeight)
                        Spacer(minLength: 0)
                    }
                }

                ShelfFilterBar(
                    filter: $filter,
                    visibleCount: count,
                    totalCount: filtered.count,
                    onSelect: {
                        interaction.scrollOffset = 0
                    }
                )
                .shelfHitArea(.filterBar)
                .position(x: width / 2, y: filterY)
                .zIndex(300)
            }
            .coordinateSpace(name: "ClipboardShelf")
            .onPreferenceChange(ShelfHitTargetsKey.self) { targets in
                onHitTargetsChanged(targets)
            }
            .preference(
                key: ShelfScrollMetricsKey.self,
                value: maxOffset
            )
            .onPreferenceChange(ShelfScrollMetricsKey.self) { maxOffset in
                onMaxScrollOffsetChanged(maxOffset)
                if maxOffset > 0.5 {
                    flashScrollHint()
                }
            }
            .onChange(of: scrollOffset) { _, _ in
                flashScrollHint()
            }
            .animation(Theme.gentleSpring, value: count)
            // A new generated copy usually replaces the oldest card, so the
            // count stays the same. Animate by item identity as well so the
            // insertion still drops the new card onto the line smoothly.
            .animation(
                Theme.gentleSpring,
                value: loadedItems.map(\.id)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func flashScrollHint() {
        let token = UUID()
        scrollHintToken = token
        withAnimation(.easeOut(duration: 0.12)) {
            scrollHintVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard scrollHintToken == token else { return }
            withAnimation(.easeIn(duration: 0.35)) {
                scrollHintVisible = false
            }
        }
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
        // Let the released card fall away instead of fading in place; the
        // remaining cards slide in with the same accelerating curve.
        withAnimation(.easeIn(duration: 0.75)) {
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
                        Color.primary.opacity(0.46),
                        Color.primary.opacity(0.32),
                        Color.primary.opacity(0.46)
                    ]),
                    startPoint: CGPoint(x: start, y: lineY),
                    endPoint: CGPoint(x: end, y: lineY)
                ),
                lineWidth: 1.4
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

/// A short horizontal arm joining the edge rail to one card's clip loop.
private struct ShelfSideArmView: View {
    let railX: CGFloat
    let clipX: CGFloat

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            var arm = Path()
            arm.move(to: CGPoint(x: 0, y: midY))
            arm.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(
                arm,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.primary.opacity(0.46),
                        Color.primary.opacity(0.32),
                        Color.primary.opacity(0.46)
                    ]),
                    startPoint: CGPoint(x: 0, y: midY),
                    endPoint: CGPoint(x: size.width, y: midY)
                ),
                style: StrokeStyle(lineWidth: 1.3, lineCap: .round)
            )
        }
        .frame(width: max(0, abs(clipX - railX)), height: 3)
    }
}

/// A vertical peg rail for left / right edge mode. Each card hangs from a
/// short arm that reaches its clip loop; the rail stays near the screen edge.
private struct ShelfSideRackView: View, Animatable {
    var railX: CGFloat
    var start: CGFloat
    var end: CGFloat

    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        CGFloat
    > {
        get {
            AnimatablePair(AnimatablePair(start, end), railX)
        }
        set {
            start = newValue.first.first
            end = newValue.first.second
            railX = newValue.second
        }
    }

    var body: some View {
        Canvas { context, _ in
            let plateWidth: CGFloat = 20
            let plateHeight: CGFloat = 7

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

            var line = Path()
            line.move(to: CGPoint(x: railX, y: start))
            line.addLine(to: CGPoint(x: railX, y: end))
            context.stroke(
                line,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.primary.opacity(0.46),
                        Color.primary.opacity(0.32),
                        Color.primary.opacity(0.46)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - Scroll indicator

private struct ShelfScrollIndicator: View {
    let edge: ClipboardShelfEdge
    let offset: CGFloat
    let maxOffset: CGFloat
    let contentLength: CGFloat
    let viewportLength: CGFloat
    let panelWidth: CGFloat
    let panelHeight: CGFloat

    private var ratio: CGFloat {
        guard contentLength > 0 else { return 1 }
        return min(1, max(0, viewportLength / contentLength))
    }

    private var trackLength: CGFloat {
        edge.isSide ? 160 : 120
    }

    private var thumbLength: CGFloat {
        max(24, trackLength * ratio)
    }

    private var thumbStart: CGFloat {
        guard maxOffset > 0 else { return 0 }
        let progress = min(max(offset / maxOffset, 0), 1)
        return progress * (trackLength - thumbLength)
    }

    var body: some View {
        Group {
            if edge.isSide {
                verticalIndicator
                    .position(
                        x: edge == .left ? panelWidth - 10 : 10,
                        y: panelHeight / 2
                    )
            } else {
                horizontalIndicator
                    .position(
                        x: panelWidth / 2,
                        y: panelHeight
                            - ClipboardShelfLayout.filterBarBottom
                            - ClipboardShelfLayout.filterBarHeight
                            - 18
                    )
            }
        }
    }

    private var horizontalIndicator: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.06))
                .frame(width: trackLength, height: 6)

            Capsule()
                .fill(Color.primary.opacity(0.38))
                .frame(width: thumbLength, height: 3)
                .offset(x: thumbStart, y: 1.5)
        }
        .frame(width: trackLength, height: 6)
    }

    private var verticalIndicator: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(Color.primary.opacity(0.06))
                .frame(width: 6, height: trackLength)

            Capsule()
                .fill(Color.primary.opacity(0.38))
                .frame(width: 3, height: thumbLength)
                .offset(x: 1.5, y: thumbStart)
        }
        .frame(width: 6, height: trackLength)
    }
}

// MARK: - Filter bar

private struct ShelfFilterBar: View {
    @Binding var filter: ClipboardShelfFilter
    let visibleCount: Int
    let totalCount: Int
    let onSelect: () -> Void

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
        onSelect()
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
