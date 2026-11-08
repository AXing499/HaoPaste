//
//  ClipboardShelfLayout.swift
//  HaoPaste
//
//  Geometry for the top-edge clipboard shelf.
//

import AppKit
import CoreGraphics

struct ShelfHitTarget: Equatable {
    enum Kind: Equatable {
        case card(UUID)
        case filterBar
    }

    let kind: Kind
    let rect: CGRect
}

enum ClipboardShelfLayout {
    static let panelHeight: CGFloat = 232
    static let railTop: CGFloat = 8
    static let lineTop: CGFloat = 16
    static let clipHeight: CGFloat = 16
    static let clipOverlap: CGFloat = 4
    static let bodyOffset = clipHeight - clipOverlap
    static let cardBodyHeight: CGFloat = 128
    static let cardHeight = clipHeight + cardBodyHeight - clipOverlap
    static let cardTopOffset: CGFloat = -clipHeight / 2
    static let minCardHeight: CGFloat = 110
    static let maxTopCardHeight: CGFloat = 150
    static let maxSideCardHeight: CGFloat = 240
    static let textLineHeight: CGFloat = 15
    static let minCardWidth: CGFloat = 118
    static let maxCardWidth: CGFloat = 156
    static let spacing: CGFloat = 14
    static let sidePadding: CGFloat = 40
    static let rackInset: CGFloat = 16
    static let rackMargin: CGFloat = 44
    static let sidePanelWidth: CGFloat = 232
    static let sidePaddingInner: CGFloat = 38
    static let sideTopPadding: CGFloat = 28
    static let sideSpacing: CGFloat = 14
    static let sideRackInset: CGFloat = 16
    static let sideRailInset: CGFloat = 16
    static let sideRevealDepth: CGFloat = 9
    static let filterBarHeight: CGFloat = 28
    static let filterBarBottom: CGFloat = 12
    static let minSag: CGFloat = 12
    static let maxSag: CGFloat = 24

    static func totalWidth(count: Int, cardWidth: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * cardWidth + CGFloat(count - 1) * spacing
    }

    static func sideCardWidth(panelWidth: CGFloat) -> CGFloat {
        min(
            maxCardWidth,
            max(minCardWidth, panelWidth - sidePaddingInner * 2)
        )
    }

    static func cardHeight(
        for item: ClipboardItem,
        cardWidth: CGFloat,
        edge: ClipboardShelfEdge
    ) -> CGFloat {
        let maximum = edge == .top
            ? maxTopCardHeight
            : maxSideCardHeight
        let raw: CGFloat

        switch item.type {
        case .image:
            let ratio = item.imageDimensions.map {
                CGFloat($0.height) / CGFloat(max($0.width, 1))
            } ?? 0.65
            raw = bodyOffset + cardWidth * ratio

        case .colorHex:
            raw = 138

        case .text, .code, .url, .file:
            let snippet = String(item.shelfSnippet.prefix(600))
            let charactersPerLine = max(8, Int(cardWidth / 10.0))
            let wrappedLines = snippet
                .components(separatedBy: .newlines)
                .reduce(0.0) { partial, line in
                    partial + Double(
                        max(
                            1,
                            Int(
                                ceil(
                                    Double(line.count)
                                        / Double(charactersPerLine)
                                )
                            )
                        )
                    )
                }
            let maximumLines = edge.isSide ? 6 : 4
            let lines = min(maximumLines, max(1, Int(wrappedLines)))
            raw = bodyOffset
                + 68
                + CGFloat(lines) * textLineHeight
        }

        return min(maximum, max(minCardHeight, raw))
    }

    static func textLineLimit(
        forCardHeight cardHeight: CGFloat,
        isFile: Bool
    ) -> Int {
        let body = cardHeight - bodyOffset
        let lines = Int(max(0, body - 68) / textLineHeight)
        return min(isFile ? 3 : 6, max(1, lines))
    }

    static func sideCardTops(cardHeights: [CGFloat]) -> [CGFloat] {
        var tops: [CGFloat] = []
        tops.reserveCapacity(cardHeights.count)
        var y = sideTopPadding
        for height in cardHeights {
            tops.append(y)
            y += height + sideSpacing
        }
        return tops
    }

    static func sideRackRange(
        height: CGFloat,
        contentBottom: CGFloat,
        scrollable: Bool
    ) -> ClosedRange<CGFloat> {
        guard height > 0 else { return 0...0 }

        let minEnd = sideVisibleBottom(height: height) - sideRackInset

        if scrollable {
            return sideRackInset...max(sideRackInset + 8, minEnd)
        }

        if contentBottom <= 0 {
            let middle = height * 0.46
            let half: CGFloat = 90
            let start = max(sideRackInset, middle - half)
            let end = min(minEnd, middle + half)
            return start...max(start + 8, end)
        }

        let start = max(sideRackInset, sideTopPadding - 16)
        let end = min(minEnd, contentBottom + 16)
        return start...max(start + 8, end)
    }

    static func sideVisibleBottom(height: CGFloat) -> CGFloat {
        max(
            0,
            height - filterBarBottom - filterBarHeight - 12
        )
    }

    static func sideContentHeight(cardHeights: [CGFloat]) -> CGFloat {
        guard !cardHeights.isEmpty else { return 0 }
        return cardHeights.reduce(0, +)
            + CGFloat(cardHeights.count - 1) * sideSpacing
    }

    static func sideMaxScrollOffset(
        height: CGFloat,
        cardHeights: [CGFloat]
    ) -> CGFloat {
        max(
            0,
            sideContentHeight(cardHeights: cardHeights)
                + sideTopPadding * 2
                - sideVisibleBottom(height: height)
        )
    }

    static func topMaxScrollOffset(
        width: CGFloat,
        count: Int,
        cardWidth: CGFloat
    ) -> CGFloat {
        max(
            0,
            totalWidth(count: count, cardWidth: cardWidth)
                + sidePadding * 2
                - width
        )
    }

    static func topRackSpan(
        width: CGFloat,
        count: Int,
        cardWidth: CGFloat,
        scrollable: Bool
    ) -> ClosedRange<CGFloat> {
        if scrollable {
            let start = rackInset
            let end = max(start + 8, width - rackInset)
            return start...end
        }
        return rackSpan(
            width: width,
            count: count,
            cardWidth: cardWidth
        )
    }

    static func sideVisibleRange(
        cardTops: [CGFloat],
        cardHeights: [CGFloat],
        offset: CGFloat,
        height: CGFloat,
        buffer: CGFloat
    ) -> Range<Int> {
        let count = min(cardTops.count, cardHeights.count)
        guard count > 0 else { return 0..<0 }

        let visibleBottom = sideVisibleBottom(height: height)

        var first = 0
        while first < count {
            let bottom = cardTops[first] + cardHeights[first] - offset
            if bottom > -buffer { break }
            first += 1
        }

        var last = count - 1
        while last >= first {
            let top = cardTops[last] - offset
            if top < visibleBottom + buffer { break }
            last -= 1
        }

        guard first <= last else { return first..<first }
        return first..<(last + 1)
    }

    static func topVisibleRange(
        width: CGFloat,
        count: Int,
        cardWidth: CGFloat,
        offset: CGFloat,
        scrollable: Bool,
        buffer: CGFloat
    ) -> Range<Int> {
        guard count > 0 else { return 0..<0 }
        guard scrollable else { return 0..<count }

        let step = cardWidth + spacing
        let startX = sidePadding
        let lower = offset - startX - buffer - cardWidth
        let upper = offset - startX + width + buffer
        let first = max(0, Int(floor(lower / step)))
        let last = min(count, Int(ceil(upper / step)) + 1)
        return first..<max(first, last)
    }

    static func cardWidth(width: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else { return maxCardWidth }
        let available = max(0, width - sidePadding * 2)
        let raw = (available - CGFloat(count - 1) * spacing) / CGFloat(count)
        return min(maxCardWidth, max(minCardWidth, raw))
    }

    static func centerX(
        index: Int,
        count: Int,
        width: CGFloat,
        cardWidth: CGFloat
    ) -> CGFloat {
        let total = totalWidth(count: count, cardWidth: cardWidth)
        let start = (width - total) / 2
        return start + CGFloat(index) * (cardWidth + spacing) + cardWidth / 2
    }

    /// The rack is inset from the screen edges and grows with the visible
    /// cards, so a short filter result still reads as a deliberate clothesline.
    static func rackSpan(
        width: CGFloat,
        count: Int,
        cardWidth: CGFloat
    ) -> ClosedRange<CGFloat> {
        guard width > rackInset * 2 else {
            return 0...max(0, width)
        }

        let start: CGFloat
        let end: CGFloat

        if count == 0 {
            let half = min(width * 0.22, 190)
            start = width / 2 - half
            end = width / 2 + half
        } else {
            let total = totalWidth(count: count, cardWidth: cardWidth)
            let left = (width - total) / 2
            start = max(rackInset, left - rackMargin)
            end = min(width - rackInset, left + total + rackMargin)
        }

        guard end - start > 8 else {
            return (width / 2 - 4)...(width / 2 + 4)
        }
        return start...end
    }

    static func sag(span: CGFloat) -> CGFloat {
        min(maxSag, max(minSag, span * 0.018))
    }

    static func ropeY(
        x: CGFloat,
        rackStart: CGFloat,
        rackEnd: CGFloat
    ) -> CGFloat {
        let span = rackEnd - rackStart
        guard span > 1 else { return lineTop }

        let fraction = min(max((x - rackStart) / span, 0), 1)
        return lineTop + 4 * sag(span: span) * fraction * (1 - fraction)
    }

    static func menuBarBand(of screen: NSScreen) -> NSRect {
        var height = screen.frame.maxY - screen.visibleFrame.maxY
        if height < 1 {
            height = max(
                NSStatusBar.system.thickness,
                screen.safeAreaInsets.top
            )
        }

        return NSRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - height,
            width: screen.frame.width,
            height: height
        )
    }

    static func revealBand(of screen: NSScreen) -> NSRect {
        revealBand(of: screen, edge: .top)
    }

    static func revealBand(
        of screen: NSScreen,
        edge: ClipboardShelfEdge
    ) -> NSRect {
        switch edge {
        case .top:
            let band = menuBarBand(of: screen)
            let width = band.width / 3
            return NSRect(
                x: band.midX - width / 2,
                y: band.minY,
                width: width,
                height: band.height
            )

        case .left, .right:
            let visible = screen.visibleFrame
            let height = visible.height / 3
            let depth = max(
                8,
                min(12, screen.frame.width * 0.006)
            )
            return NSRect(
                x: edge == .left ? visible.minX : visible.maxX - depth,
                y: visible.midY - height / 2,
                width: depth,
                height: height
            )
        }
    }

    static func panelFrame(on screen: NSScreen) -> NSRect {
        panelFrame(on: screen, edge: .top)
    }

    static func panelFrame(
        on screen: NSScreen,
        edge: ClipboardShelfEdge
    ) -> NSRect {
        let visible = screen.visibleFrame
        switch edge {
        case .top:
            return NSRect(
                x: visible.minX,
                y: visible.maxY - panelHeight,
                width: visible.width,
                height: panelHeight
            )

        case .left:
            return NSRect(
                x: visible.minX,
                y: visible.minY,
                width: sidePanelWidth,
                height: visible.height
            )

        case .right:
            return NSRect(
                x: visible.maxX - sidePanelWidth,
                y: visible.minY,
                width: sidePanelWidth,
                height: visible.height
            )
        }
    }

    /// Place a preview / translation card next to the shelf card without
    /// covering the shelf itself.
    static func detailFrame(
        size: NSSize,
        anchor: NSRect,
        edge: ClipboardShelfEdge
    ) -> NSRect {
        let screen = NSScreen.screens.first {
            $0.frame.intersects(anchor)
        } ?? NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else {
            return NSRect(origin: anchor.origin, size: size)
        }

        let gap: CGFloat = 14
        let margin: CGFloat = 12
        var x: CGFloat
        var y: CGFloat

        switch edge {
        case .top:
            let shelfBottom = visible.maxY - panelHeight
            x = anchor.midX - size.width / 2
            y = shelfBottom - gap - size.height
        case .left:
            x = visible.minX + sidePanelWidth + gap
            y = anchor.midY - size.height / 2
        case .right:
            x = visible.maxX - sidePanelWidth - gap - size.width
            y = anchor.midY - size.height / 2
        }

        x = min(max(x, visible.minX + margin), visible.maxX - size.width - margin)
        y = min(max(y, visible.minY + margin), visible.maxY - size.height - margin)

        return NSRect(
            x: x.rounded(.down),
            y: y.rounded(.down),
            width: size.width,
            height: size.height
        )
    }

    static func hoverOffset(for edge: ClipboardShelfEdge) -> CGSize {
        switch edge {
        case .top: return CGSize(width: 0, height: -5)
        case .left: return CGSize(width: 8, height: 0)
        case .right: return CGSize(width: -8, height: 0)
        }
    }

    static func slideOffset(
        for edge: ClipboardShelfEdge,
        distance: CGFloat
    ) -> CGSize {
        switch edge {
        case .top: return CGSize(width: 0, height: distance)
        case .left: return CGSize(width: -distance, height: 0)
        case .right: return CGSize(width: distance, height: 0)
        }
    }

    static func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(mouse, $0.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// A full-screen app covers the whole display, including the menu bar.
    /// Normal maximized windows stop at `visibleFrame`, so they do not count.
    /// Point is in top-left (SwiftUI) panel coordinates.
    static func hitTest(_ point: CGPoint, in rects: [CGRect]) -> Bool {
        rects.contains { $0.insetBy(dx: -4, dy: -4).contains(point) }
    }

    static func hitTarget(
        at point: CGPoint,
        in targets: [ShelfHitTarget]
    ) -> ShelfHitTarget? {
        let hits = targets.filter {
            $0.rect.insetBy(dx: -4, dy: -4).contains(point)
        }
        // Side cards can scroll under the floating filter bar; the bar is
        // visually on top, so it must win hit testing in the overlap.
        return hits.first { $0.kind == .filterBar } ?? hits.first
    }

    static func isFullScreen(on screen: NSScreen) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard
            let windows = CGWindowListCopyWindowInfo(
                options,
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return false
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier

        for window in windows {
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }

            let ownerPID = window[kCGWindowOwnerPID as String] as? Int ?? 0
            guard ownerPID != Int(ownPID) else { continue }

            guard
                let boundsDictionary = window[kCGWindowBounds as String]
                    as? [String: Any],
                let bounds = CGRect(
                    dictionaryRepresentation: boundsDictionary as CFDictionary
                )
            else {
                continue
            }

            if bounds.width >= screen.frame.width - 2,
               bounds.height >= screen.frame.height - 2 {
                return true
            }
        }

        return false
    }
}
