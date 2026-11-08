//
//  ClipboardShelfController.swift
//  HaoPaste
//
//  Owns the top-edge clipboard shelf: trigger polling, reveal/retract and
//  click-through outside the actual cards.
//

import AppKit
import SwiftUI

@MainActor
final class ClipboardShelfController: NSObject {
    private enum Timing {
        static let visiblePollInterval: TimeInterval = 1.0 / 30.0
        static let hiddenPollInterval: TimeInterval = 1.0 / 10.0
        static let revealDelay: TimeInterval = 0.25
        static let retractDelay: TimeInterval = 0.5
    }

    private let manager: ClipboardManager
    private let settings: AppSettings
    private let panel: ClipboardShelfPanel

    private var mouseTimer: Timer?
    private var pollInterval: TimeInterval?
    private var menuClickMonitors: [Any] = []
    private var spaceChangeObserver: NSObjectProtocol?
    private var screenChangeObserver: NSObjectProtocol?

    private var isRevealed = false
    private var isHiding = false
    private var manualOpen = false
    private var manualVisited = false
    private var hotZoneSince: Date?
    private var awaySince: Date?
    private let hitTargetStore: ShelfHitTargetStore
    private let interaction: ShelfInteractionState
    private let actionRelay: ShelfActionRelay
    private var menuBarSuppressed = false

    var onVisibilityChanged: (() -> Void)?
    var onPreviewItem: ((ClipboardItem) -> Void)?
    /// Return true while another HaoPaste window owns the screen.
    var isRevealBlocked: (() -> Bool)?

    var isShowing: Bool {
        isRevealed
    }

    init(manager: ClipboardManager, settings: AppSettings) {
        self.manager = manager
        self.settings = settings

        let hitTargetStore = ShelfHitTargetStore()
        self.hitTargetStore = hitTargetStore

        let interactionState = ShelfInteractionState()
        self.interaction = interactionState

        let actionRelay = ShelfActionRelay()
        self.actionRelay = actionRelay

        let rootView = ClipboardShelfView(
            manager: manager,
            settings: settings,
            interaction: interactionState,
            onHitTargetsChanged: { targets in
                hitTargetStore.targets = targets
            },
            onPreviewItem: { item in
                actionRelay.onPreview?(item)
            }
        )
        let hostingView = ShelfHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        self.panel = ClipboardShelfPanel(contentView: hostingView)

        super.init()

        actionRelay.onPreview = { [weak self] item in
            self?.onPreviewItem?(item)
        }

        if let screen = ClipboardShelfLayout.screenUnderPointer() {
            placePanel(on: screen)
        }

        installMenuBarClickMonitors()
        observeSpaceAndScreenChanges()

        if settings.shelfEnabled {
            startMouseTracking(interval: Timing.hiddenPollInterval)
        }
    }

    deinit {
        mouseTimer?.invalidate()
        for monitor in menuClickMonitors {
            NSEvent.removeMonitor(monitor)
        }
        if let spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceChangeObserver)
        }
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    // MARK: - Enable / disable

    func setEnabled(_ enabled: Bool) {
        if enabled {
            menuBarSuppressed = false
            startMouseTracking(interval: Timing.hiddenPollInterval)
        } else {
            stopMouseTracking()
            hide()
        }
    }

    func hideIfVisible() {
        hide()
    }

    func toggle() {
        if isRevealed {
            hide()
            return
        }

        guard settings.shelfEnabled else { return }
        guard let screen = ClipboardShelfLayout.screenUnderPointer() else {
            return
        }

        manualOpen = true
        manualVisited = false
        menuBarSuppressed = false
        reveal(on: screen)
    }

    /// `NSApp.isActive` can become true when the nonactivating panel becomes
    /// key, even though another app remains frontmost. Use the workspace's
    /// frontmost app so re-opening the shelf keeps working after a copy.
    private var isAppFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
            == ProcessInfo.processInfo.processIdentifier
    }

    // MARK: - Mouse tracking

    private func startMouseTracking(interval: TimeInterval) {
        if mouseTimer != nil, pollInterval == interval {
            return
        }

        mouseTimer?.invalidate()

        let timer = Timer(timeInterval: interval, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        mouseTimer = timer
        pollInterval = interval
    }

    private func stopMouseTracking() {
        mouseTimer?.invalidate()
        mouseTimer = nil
        pollInterval = nil
        hotZoneSince = nil
        awaySince = nil
    }

    private func tick() {
        guard settings.shelfEnabled, !isHiding else { return }

        let mouse = NSEvent.mouseLocation
        let screen = ClipboardShelfLayout.screenUnderPointer()
        let inMenuBar = screen.map {
            NSMouseInRect(mouse, ClipboardShelfLayout.menuBarBand(of: $0), false)
        } ?? false

        if !inMenuBar {
            menuBarSuppressed = false
        }

        if !isRevealed {
            guard
                let screen,
                !manager.items.isEmpty,
                !isAppFrontmost,
                !menuBarSuppressed,
                isRevealBlocked?() != true
            else {
                hotZoneSince = nil
                return
            }

            let revealBand = ClipboardShelfLayout.revealBand(of: screen)
            guard NSMouseInRect(mouse, revealBand, false) else {
                hotZoneSince = nil
                return
            }

            let now = Date()
            let since = hotZoneSince ?? now
            hotZoneSince = since

            guard now.timeIntervalSince(since) >= Timing.revealDelay else {
                return
            }

            if ClipboardShelfLayout.isFullScreen(on: screen) {
                hotZoneSince = nil
                return
            }

            hotZoneSince = nil
            reveal(on: screen)
            return
        }

        updateMousePassThrough(mouse: mouse)

        var zone = panel.frame
        if let screen = panel.screen {
            // Extend the zone to the top of the screen so moving up into the
            // menu bar to use a menu does not retract the shelf.
            zone.size.height = screen.frame.maxY - zone.minY
        }

        let inside = NSMouseInRect(mouse, zone, false)

        if inside {
            awaySince = nil
            if manualOpen {
                manualVisited = true
            }
        } else if manualOpen && !manualVisited {
            // Opened from the menu or a shortcut: wait until the pointer has
            // visited the shelf before starting the retract timer.
            awaySince = nil
        } else {
            let now = Date()
            let since = awaySince ?? now
            awaySince = since

            if now.timeIntervalSince(since) >= Timing.retractDelay {
                awaySince = nil
                hide()
            }
        }
    }

    /// The panel spans the whole screen; only the cards and filter bar should
    /// accept mouse events. Everywhere else clicks pass through.
    private func updateMousePassThrough(mouse: NSPoint) {
        guard isRevealed, !isHiding else {
            panel.ignoresMouseEvents = true
            interaction.hoveredItemID = nil
            return
        }

        let local = panel.convertPoint(fromScreen: mouse)
        let flipped = CGPoint(
            x: local.x,
            y: panel.frame.height - local.y
        )

        let target = ClipboardShelfLayout.hitTarget(
            at: flipped,
            in: hitTargetStore.targets
        )
        let hoveredID: UUID?
        if case let .card(id) = target?.kind {
            hoveredID = id
        } else {
            hoveredID = nil
        }
        if interaction.hoveredItemID != hoveredID {
            interaction.hoveredItemID = hoveredID
        }

        let acceptsMouse = target != nil
        if panel.ignoresMouseEvents == acceptsMouse {
            panel.ignoresMouseEvents = !acceptsMouse
        }
    }

    // MARK: - Reveal / retract

    private func reveal(on screen: NSScreen) {
        guard !isHiding else { return }

        placePanel(on: screen)

        let target = ClipboardShelfLayout.panelFrame(on: screen)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let start = reduceMotion
            ? target
            : target.offsetBy(dx: 0, dy: 12)

        panel.alphaValue = reduceMotion ? 1 : 0
        panel.setFrame(start, display: false)
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        isRevealed = true
        awaySince = nil
        interaction.hoveredItemID = nil
        startMouseTracking(interval: Timing.visiblePollInterval)

        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.16, 1, 0.3, 1
                )
                panel.animator().alphaValue = 1
                panel.animator().setFrame(target, display: true)
            }
        }

        onVisibilityChanged?()
    }

    private func hide() {
        guard isRevealed, !isHiding else { return }

        isRevealed = false
        isHiding = true
        interaction.hoveredItemID = nil
        startMouseTracking(interval: Timing.hiddenPollInterval)
        manualOpen = false
        manualVisited = false
        hotZoneSince = nil
        awaySince = nil
        panel.ignoresMouseEvents = true

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        let target = screen.map(ClipboardShelfLayout.panelFrame(on:)) ?? panel.frame
        let end = reduceMotion
            ? target
            : target.offsetBy(dx: 0, dy: 10)

        let finish = { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            self.panel.setFrame(target, display: false)
            self.isHiding = false
            self.onVisibilityChanged?()
        }

        guard !reduceMotion else {
            finish()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(end, display: true)
        } completionHandler: {
            DispatchQueue.main.async(execute: finish)
        }
    }

    private func placePanel(on screen: NSScreen) {
        let frame = ClipboardShelfLayout.panelFrame(on: screen)
        if panel.frame != frame {
            panel.setFrame(frame, display: false)
        }
    }

    // MARK: - Menu bar clicks

    private func installMenuBarClickMonitors() {
        let handler: (NSEvent?) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMenuBarClick()
            }
        }

        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: handler
        ) {
            menuClickMonitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { event in
                handler(event)
                return event
            }
        ) {
            menuClickMonitors.append(local)
        }
    }

    private func handleMenuBarClick() {
        let mouse = NSEvent.mouseLocation
        guard let screen = ClipboardShelfLayout.screenUnderPointer(),
              NSMouseInRect(
                  mouse,
                  ClipboardShelfLayout.menuBarBand(of: screen),
                  false
              )
        else {
            return
        }

        menuBarSuppressed = true
        hotZoneSince = nil

        if isRevealed {
            hide()
        }
    }

    // MARK: - Application / space changes

    private func observeSpaceAndScreenChanges() {
        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRevealed else { return }
                self.hide()
            }
        }

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRevealed else { return }
                self.hide()
            }
        }
    }
}

private final class ShelfHitTargetStore {
    var targets: [ShelfHitTarget] = []
}

private final class ShelfActionRelay {
    var onPreview: ((ClipboardItem) -> Void)?
}

/// The shelf is shown while another app is active, so the first click must
/// reach the card instead of being consumed by window activation.
private final class ShelfHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
