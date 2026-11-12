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
        let backRect = NSRect(x: 2.8, y: 9.5, width: 13.5, height: 12.0)
        let frontRect = NSRect(x: 13.2, y: 6.0, width: 12.8, height: 12.5)
        let back = NSBezierPath(
            roundedRect: backRect,
            xRadius: 3.3,
            yRadius: 3.3
        )
        let front = NSBezierPath(
            roundedRect: frontRect,
            xRadius: 3.7,
            yRadius: 3.7
        )

        NSColor.black.setFill()
        back.fill()

        let gap = NSBezierPath(
            roundedRect: frontRect.insetBy(dx: -1.4, dy: -1.4),
            xRadius: 4.6,
            yRadius: 4.6
        )
        setCompositing(.destinationOut)
        gap.fill()
        setCompositing(.sourceOver)

        front.fill()

        switch direction {
        case .down:
            tail(
                NSPoint(x: 19.8, y: 6.3),
                NSPoint(x: 23.2, y: 6.3),
                NSPoint(x: 21.5, y: 3.0)
            )
        case .up:
            tail(
                NSPoint(x: 19.8, y: 18.5),
                NSPoint(x: 23.2, y: 18.5),
                NSPoint(x: 21.5, y: 21.8)
            )
        case .left:
            tail(
                NSPoint(x: 3.0, y: 11.5),
                NSPoint(x: 3.0, y: 15.0),
                NSPoint(x: 0.5, y: 12.2)
            )
        case .right:
            tail(
                NSPoint(x: 26.0, y: 9.8),
                NSPoint(x: 26.0, y: 13.3),
                NSPoint(x: 27.8, y: 10.2)
            )
        }

        glyph("A", center: NSPoint(x: 7.3, y: 15.7), size: 8.6)
        glyph("文", center: NSPoint(x: 19.6, y: 12.2), size: 9.0)
    }

    private static func tail(_ a: NSPoint, _ b: NSPoint, _ tip: NSPoint) {
        let path = NSBezierPath()
        path.move(to: a)
        path.line(to: tip)
        path.line(to: b)
        path.close()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = 1.4
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
