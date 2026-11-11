//
//  Theme.swift
//  HaoPaste
//
//  Shared visual tokens. Everything is built on system semantic colors.
//

import AppKit
import SwiftUI

enum DebugMotion {
    /// Screenshot/UI snapshot renders can disable animations so captures are
    /// byte-for-byte deterministic.
    static var disablesAnimations: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment[
            "HAOPASTE_RENDER_DISABLE_ANIMATIONS"
        ] == "1"
        #else
        false
        #endif
    }
}

enum Theme {
    // Geometry
    static let panelCornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 10
    static let iconCornerRadius: CGFloat = 9
    static let hairline: CGFloat = 0.5

    static let panelSize = CGSize(width: 720, height: 560)
    static let windowPadding: CGFloat = 0
    static let windowSize = CGSize(
        width: panelSize.width + windowPadding * 2,
        height: panelSize.height + windowPadding * 2
    )

    static let contentPadding: CGFloat = 14
    static let rowSpacing: CGFloat = 6

    // Shapes
    static let panelShape = RoundedRectangle(
        cornerRadius: panelCornerRadius,
        style: .continuous
    )

    static let cardShape = RoundedRectangle(
        cornerRadius: cardCornerRadius,
        style: .continuous
    )

    // Motion — the spring used across hover, selection and list updates.
    static let spring = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let gentleSpring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let quickSpring = Animation.spring(response: 0.2, dampingFraction: 0.76)
    static let shelfDropSpring = Animation.spring(response: 0.34, dampingFraction: 0.72)

    // Borders
    static let hairlineColor = Color.primary.opacity(0.08)
    static let subtleBorderColor = Color.primary.opacity(0.06)

    // Floating panes: an opaque system surface keeps every popover the same
    // brightness even when it floats over dark page or desktop content.
    static let popoverBackground = Color(nsColor: .windowBackgroundColor)

    // Typography helpers
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

extension View {
    /// Shows the standard pointing-hand cursor while the pointer is over an
    /// actionable custom view (SwiftUI buttons do not draw it automatically).
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }

    /// A 0.5 pt inset border that follows the provided squircle shape.
    func hairlineStroke<S: InsettableShape>(
        _ shape: S,
        color: Color = Theme.hairlineColor
    ) -> some View {
        overlay {
            shape.strokeBorder(color, lineWidth: Theme.hairline)
        }
    }
}


private struct PointingHandCursorModifier: ViewModifier {
    @State private var isPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering {
                    guard !isPushed else { return }
                    NSCursor.pointingHand.push()
                    isPushed = true
                } else if isPushed {
                    NSCursor.pop()
                    isPushed = false
                }
            }
            .onDisappear {
                guard isPushed else { return }
                NSCursor.pop()
                isPushed = false
            }
    }
}
