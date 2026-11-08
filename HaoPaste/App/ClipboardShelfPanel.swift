//
//  ClipboardShelfPanel.swift
//  HaoPaste
//
//  Transparent, nonactivating panel that hosts the top clipboard shelf.
//

import AppKit

final class ClipboardShelfPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// The shelf must be allowed to start fully outside the screen so the
    /// reveal can slide the whole panel in from the chosen edge. AppKit would
    /// otherwise clamp a frame above the menu bar back onto the screen and
    /// the top reveal would jump straight to its final position.
    override func constrainFrameRect(
        _ frameRect: NSRect,
        to screen: NSScreen?
    ) -> NSRect {
        frameRect
    }
}
