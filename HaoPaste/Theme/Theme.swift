//
//  Theme.swift
//  HaoPaste
//
//  Shared visual tokens. Everything is built on system semantic colors.
//

import SwiftUI

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

    // Borders
    static let hairlineColor = Color.primary.opacity(0.08)
    static let subtleBorderColor = Color.primary.opacity(0.06)

    // Typography helpers
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

extension View {
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
