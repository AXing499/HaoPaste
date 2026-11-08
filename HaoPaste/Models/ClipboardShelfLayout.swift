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
    static let filterBarHeight: CGFloat = 28
    static let filterBarBottom: CGFloat = 12
    static let minSag: CGFloat = 12
    static let maxSag: CGFloat = 24

    static func capacity(width: CGFloat, limit: Int) -> Int {
        let available = max(0, width - sidePadding * 2)
        let fitting = Int((available + spacing) / (minCardWidth + spacing))
        return max(1, min(limit, max(1, fitting)))
    }

    static func totalWidth(count: Int, cardWidth: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * cardWidth + CGFloat(count - 1) * spacing
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
        let band = menuBarBand(of: screen)
        let width = band.width / 3
        return NSRect(
            x: band.midX - width / 2,
            y: band.minY,
            width: width,
            height: band.height
        )
    }

    static func panelFrame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        return NSRect(
            x: visible.minX,
            y: visible.maxY - panelHeight,
            width: visible.width,
            height: panelHeight
        )
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
        targets.first { $0.rect.insetBy(dx: -4, dy: -4).contains(point) }
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
