//
//  SelectionTranslationLayout.swift
//  HaoPaste
//
//  Pure placement rules for the selection icon and translation card.
//

import AppKit

struct SelectionTranslationIconPlacement {
    let frame: NSRect
    let direction: SelectionTranslationIconDirection
}

enum SelectionTranslationLayout {
    static func iconFrame(
        anchor: NSPoint,
        size: CGFloat,
        visibleFrame: NSRect
    ) -> NSRect {
        iconPlacement(
            anchor: anchor,
            size: size,
            visibleFrame: visibleFrame
        ).frame
    }

    static func iconPlacement(
        anchor: NSPoint,
        size: CGFloat,
        visibleFrame: NSRect
    ) -> SelectionTranslationIconPlacement {
        let gap: CGFloat = 3
        let margin: CGFloat = 8
        let bounds = visibleFrame.insetBy(dx: margin, dy: margin)
        let centeredX = anchor.x - size / 2
        let centeredY = anchor.y - size / 2

        let candidates: [(NSRect, SelectionTranslationIconDirection)] = [
            (
                NSRect(
                    x: centeredX,
                    y: anchor.y + gap,
                    width: size,
                    height: size
                ),
                .down
            ),
            (
                NSRect(
                    x: centeredX,
                    y: anchor.y - size - gap,
                    width: size,
                    height: size
                ),
                .up
            ),
            (
                NSRect(
                    x: anchor.x + gap,
                    y: centeredY,
                    width: size,
                    height: size
                ),
                .left
            ),
            (
                NSRect(
                    x: anchor.x - size - gap,
                    y: centeredY,
                    width: size,
                    height: size
                ),
                .right
            )
        ]

        for (frame, direction) in candidates {
            let integral = frame.integral
            if bounds.contains(integral) {
                return SelectionTranslationIconPlacement(
                    frame: integral,
                    direction: direction
                )
            }
        }

        let fallback = candidates.max { lhs, rhs in
            let left = lhs.0.intersection(bounds)
            let right = rhs.0.intersection(bounds)
            return left.width * left.height < right.width * right.height
        } ?? candidates[0]
        let frame = fallback.0
        let clamped = NSRect(
            x: min(
                max(frame.minX, bounds.minX),
                bounds.maxX - size
            ),
            y: min(
                max(frame.minY, bounds.minY),
                bounds.maxY - size
            ),
            width: size,
            height: size
        ).integral
        return SelectionTranslationIconPlacement(
            frame: clamped,
            direction: fallback.1
        )
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
