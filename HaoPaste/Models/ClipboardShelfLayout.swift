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
    static let clipHeight: CGFloat = 14
    static let clipOverlap: CGFloat = 3
    static let bodyOffset = clipHeight - clipOverlap
    static let cardBodyHeight: CGFloat = 129
    static let cardHeight = clipHeight + cardBodyHeight - clipOverlap
    static let cardTopOffset: CGFloat = -clipHeight / 2
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

    static func sideCardTop(index: Int) -> CGFloat {
        sideTopPadding + CGFloat(index) * (cardHeight + sideSpacing)
    }

    static func sideRackRange(
        height: CGFloat,
        count: Int,
        scrollable: Bool = false
    ) -> ClosedRange<CGFloat> {
        guard height > 0 else { return 0...0 }

        let minEnd = sideVisibleBottom(height: height) - sideRackInset

        if scrollable {
            return sideRackInset...max(sideRackInset + 8, minEnd)
        }

        if count == 0 {
            let middle = height * 0.46
            let half: CGFloat = 90
            let start = max(sideRackInset, middle - half)
            let end = min(minEnd, middle + half)
            return start...max(start + 8, end)
        }

        let start = max(sideRackInset, sideTopPadding - 16)
        let end = min(
            minEnd,
            sideCardTop(index: count - 1) + cardHeight + 16
        )
        return start...max(start + 8, end)
    }

    static func sideVisibleBottom(height: CGFloat) -> CGFloat {
        max(
            0,
            height - filterBarBottom - filterBarHeight - 12
        )
    }

    static func sideContentHeight(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * cardHeight
            + CGFloat(count - 1) * sideSpacing
    }

    static func sideMaxScrollOffset(
        height: CGFloat,
        count: Int
    ) -> CGFloat {
        max(
            0,
            sideContentHeight(count: count)
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
        count: Int,
        offset: CGFloat,
        height: CGFloat,
        buffer: CGFloat
    ) -> Range<Int> {
        guard count > 0 else { return 0..<0 }

        let step = cardHeight + sideSpacing
        let visibleBottom = sideVisibleBottom(height: height)
        let lower = offset - sideTopPadding - buffer - cardHeight
        let upper = offset - sideTopPadding + visibleBottom + buffer
        let first = max(0, Int(floor(lower / step)))
        let last = min(count, Int(ceil(upper / step)) + 1)
        return first..<max(first, last)
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
