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

    /// Bumped once the revealed panel is actually on screen. Glass surfaces
    /// use this to rebuild their AppKit views; a panel that was laid out while
    /// hidden can otherwise keep a stale material render until the next hover
    /// update happens to refresh SwiftUI.
    var glassRefreshToken = 0

}
