//
//  ShelfInteractionState.swift
//  HaoPaste
//
//  Pointer state shared by the shelf controller and cards.
//

import Foundation
import Observation

@MainActor
@Observable
final class ShelfInteractionState {
    /// Driven by the controller's hit testing rather than SwiftUI onHover, so
    /// the highlight never sticks when click-through toggles between cards.
    var hoveredItemID: UUID?

    /// Points scrolled from the leading edge. The controller clamps this
    /// against the metrics reported by the shelf layout.
    var scrollOffset: CGFloat = 0

    /// 0...1 reveal mask so the shelf grows out from its edge.
    var revealProgress: CGFloat = 1
}
