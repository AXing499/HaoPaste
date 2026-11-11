//
//  SelectionTranslationLayout.swift
//  HaoPaste
//
//  Pure placement rules for the selection icon and translation card.
//

import AppKit

enum SelectionTranslationLayout {
    static func iconFrame(
        anchor: NSPoint,
        size: CGFloat,
        visibleFrame: NSRect
    ) -> NSRect {
        let gap: CGFloat = 3
        var x = anchor.x + gap
        var y = anchor.y - size - gap

        if y < visibleFrame.minY + 8 {
            y = anchor.y + gap
        }
        if x + size > visibleFrame.maxX - 8 {
            x = anchor.x - size - gap
        }

        x = min(max(x, visibleFrame.minX + 8), visibleFrame.maxX - size - 8)
        y = min(max(y, visibleFrame.minY + 8), visibleFrame.maxY - size - 8)

        return NSRect(x: x, y: y, width: size, height: size).integral
    }

    static func cardFrame(
        anchor: NSPoint,
        size: NSSize,
        visibleFrame: NSRect
    ) -> NSRect {
        let gap: CGFloat = 10
        var x = anchor.x + gap
        var y = anchor.y - size.height - gap

        if y < visibleFrame.minY + 8 {
            y = anchor.y + gap
        }
        if x + size.width > visibleFrame.maxX - 8 {
            x = anchor.x - size.width - gap
        }

        x = min(max(x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        y = min(max(y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)

        return NSRect(
            origin: NSPoint(x: x.rounded(.down), y: y.rounded(.down)),
            size: size
        )
    }
}
