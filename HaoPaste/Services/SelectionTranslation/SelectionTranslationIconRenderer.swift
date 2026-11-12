//
//  SelectionTranslationIconRenderer.swift
//  HaoPaste
//
//  Directional translate glyph used by the selection translation icon.
//  The SF Symbol's bubble tails always point down; this renderer keeps the
//  A / 文 bubbles upright while rotating the tail toward the selection.
//

import AppKit

enum SelectionTranslationIconDirection: CaseIterable {
    case up
    case down
    case left
    case right
}

@MainActor
enum SelectionTranslationIconRenderer {
    private static let designCanvas: CGFloat = 28
    private static let iconSize = NSSize(width: 20, height: 20)
    private static var cache: [
        SelectionTranslationIconDirection: NSImage
    ] = [:]

    static func image(
        for direction: SelectionTranslationIconDirection
    ) -> NSImage {
        if let cached = cache[direction] {
            return cached
        }

        let image = NSImage(size: iconSize, flipped: false) { rect in
            let scale = rect.width / designCanvas
            NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
            draw(direction: direction)
            return true
        }
        image.isTemplate = true
        cache[direction] = image
        return image
    }

    private static func draw(direction: SelectionTranslationIconDirection) {
        let backRect = NSRect(x: 3.5, y: 9.5, width: 12, height: 12.5)
        let frontRect = NSRect(x: 12.0, y: 6.0, width: 13, height: 13)
        let back = NSBezierPath(
            roundedRect: backRect,
            xRadius: 3.4,
            yRadius: 3.4
        )
        let front = NSBezierPath(
            roundedRect: frontRect,
            xRadius: 3.8,
            yRadius: 3.8
        )

        NSColor.black.setFill()
        back.fill()

        let gap = NSBezierPath(
            roundedRect: frontRect.insetBy(dx: -1.5, dy: -1.5),
            xRadius: 4.8,
            yRadius: 4.8
        )
        setCompositing(.destinationOut)
        gap.fill()
        setCompositing(.sourceOver)

        front.fill()

        switch direction {
        case .down:
            tail(
                NSPoint(x: 18.8, y: 6.4),
                NSPoint(x: 22.5, y: 6.4),
                NSPoint(x: 20.0, y: 2.7)
            )
        case .up:
            tail(
                NSPoint(x: 18.8, y: 18.7),
                NSPoint(x: 22.5, y: 18.7),
                NSPoint(x: 20.0, y: 22.6)
            )
        case .left:
            tail(
                NSPoint(x: 4.1, y: 11.8),
                NSPoint(x: 4.1, y: 15.4),
                NSPoint(x: 1.0, y: 12.4)
            )
        case .right:
            tail(
                NSPoint(x: 24.4, y: 9.8),
                NSPoint(x: 24.4, y: 13.4),
                NSPoint(x: 26.6, y: 10.2)
            )
        }

        glyph("A", center: NSPoint(x: 7.2, y: 16.9), size: 8.6)
        glyph("文", center: NSPoint(x: 18.5, y: 12.5), size: 9.2)
    }

    private static func tail(_ a: NSPoint, _ b: NSPoint, _ tip: NSPoint) {
        let path = NSBezierPath()
        path.move(to: a)
        path.line(to: tip)
        path.line(to: b)
        path.close()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = 1.5
        NSColor.black.setFill()
        path.fill()
        path.stroke()
    }

    private static func glyph(
        _ text: String,
        center: NSPoint,
        size: CGFloat
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: roundedFont(size: size),
            .foregroundColor: NSColor.black
        ]
        let string = text as NSString
        let bounds = string.size(withAttributes: attributes)
        let point = NSPoint(
            x: center.x - bounds.width / 2,
            y: center.y - bounds.height / 2
        )
        setCompositing(.destinationOut)
        string.draw(at: point, withAttributes: attributes)
        setCompositing(.sourceOver)
    }

    private static func roundedFont(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .bold)
        guard
            let descriptor = base.fontDescriptor.withDesign(.rounded),
            let font = NSFont(descriptor: descriptor, size: size)
        else {
            return base
        }
        return font
    }

    private static func setCompositing(
        _ operation: NSCompositingOperation
    ) {
        NSGraphicsContext.current?.compositingOperation = operation
    }
}
