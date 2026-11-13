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
        /// Rebuild glass once the revealed panel has actually entered the
        /// screen. Before that the window is still outside the display and
        /// glass can keep a stale material render until the next hover update.
        static let revealGlassRefreshDelay: TimeInterval = 0.10
    }

    private let manager: ClipboardManager
    private let settings: AppSettings
    private let panel: ClipboardShelfPanel
    private let shelfHostingView: NSView
    private let overlayHost: ShelfOverlayHost
    private var overlayContentView: NSView?
    private var overlayDetailFrame: NSRect?
    private var shelfFrameWithoutOverlay: NSRect?

    private var mouseTimer: Timer?
    private var pollInterval: TimeInterval?
    private var menuClickMonitors: [Any] = []
    private var spaceChangeObserver: NSObjectProtocol?
    private var screenChangeObserver: NSObjectProtocol?

    private var isRevealed = false
    private var isHiding = false
    private var isRevealing = false
    private var isPointerHandPushed = false
    private var activationRestoreApp: NSRunningApplication?
    private var manualOpen = false
    private var manualVisited = false
    private var hotZoneSince: Date?
    private var awaySince: Date?
    private let hitTargetStore: ShelfHitTargetStore
    private let interaction: ShelfInteractionState
    private let actionRelay: ShelfActionRelay
    private var menuBarSuppressed = false
    private var maxScrollOffset: CGFloat = 0

    var onVisibilityChanged: (() -> Void)?
    var onPreviewItem: ((ClipboardItem, NSRect?) -> Void)?
    var onTranslateItem: ((ClipboardItem, NSRect?) -> Void)?
    var onWillHide: (() -> Void)?
    var isRetractBlocked: (() -> Bool)?
    /// Return true while another HaoPaste window owns the screen.
    var isRevealBlocked: (() -> Bool)?

    var isShowing: Bool {
        isRevealed
    }

    /// Detail panels presented from the shelf can keep the shelf as the key
    /// window, which preserves Liquid Glass's active appearance.
    var isKeyForDetailPresentation: Bool {
        isRevealed && !isHiding && panel.isKeyWindow
    }

    var currentEdge: ClipboardShelfEdge {
        settings.shelfEdge
    }

    /// Present a detail surface in the shelf's own key window. This keeps
    /// Liquid Glass active while the popup is open.
    func presentOverlay(
        _ content: AnyView,
        size: CGSize,
        anchor: NSRect,
        edge: ClipboardShelfEdge
    ) {
        dismissOverlay()

        let shelfFrame = panel.frame
        let detailFrame = ClipboardShelfLayout.centeredDetailFrame(
            size: size,
            anchor: anchor
        )
        let union = shelfFrame.union(detailFrame)
        shelfFrameWithoutOverlay = shelfFrame
        overlayDetailFrame = detailFrame

        let localShelf = NSRect(
            x: shelfFrame.minX - union.minX,
            y: shelfFrame.minY - union.minY,
            width: shelfFrame.width,
            height: shelfFrame.height
        )
        let localDetail = NSRect(
            x: detailFrame.minX - union.minX,
            y: detailFrame.minY - union.minY,
            width: detailFrame.width,
            height: detailFrame.height
        )

        panel.setFrame(union, display: false)
        shelfHostingView.autoresizingMask = []
        shelfHostingView.frame = localShelf
        overlayHost.autoresizingMask = []
        overlayHost.frame = NSRect(origin: .zero, size: union.size)

        let overlay = ShelfOverlayHostingView(rootView: content)
        overlay.sizingOptions = []
        overlay.frame = localDetail
        overlay.autoresizingMask = []
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.clear.cgColor
        overlayHost.addSubview(overlay)
        overlayContentView = overlay

        panel.ignoresMouseEvents = false
        panel.makeKey()
        forcePanelDisplay()

    }

    func dismissOverlay() {
        resetOverlayState()
    }



    private func resetOverlayState() {
        overlayContentView?.removeFromSuperview()
        overlayContentView = nil
        overlayDetailFrame = nil

        guard let shelfFrame = shelfFrameWithoutOverlay else { return }
        shelfFrameWithoutOverlay = nil
        panel.setFrame(shelfFrame, display: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        let bounds = panel.contentView?.bounds
            ?? NSRect(origin: .zero, size: shelfFrame.size)
        shelfHostingView.autoresizingMask = []
        shelfHostingView.frame = NSRect(origin: .zero, size: bounds.size)
        overlayHost.autoresizingMask = []
        overlayHost.frame = NSRect(origin: .zero, size: bounds.size)
        shelfHostingView.autoresizingMask = [.width, .height]
        overlayHost.autoresizingMask = [.width, .height]
        forcePanelDisplay()
    }

    private var shelfScreenFrame: NSRect {
        let windowRect = shelfHostingView.convert(
            shelfHostingView.bounds,
            to: nil
        )
        return panel.convertToScreen(windowRect)
    }

    private var edge: ClipboardShelfEdge {
        settings.shelfEdge
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
            },
            onTranslateItem: { item in
                actionRelay.onTranslate?(item)
            },
            onMaxScrollOffsetChanged: { maxOffset in
                actionRelay.onMaxScrollOffset?(maxOffset)
            },
            onHideShelf: {
                actionRelay.onHideShelf?()
            },
            onRestoreFocus: {
                actionRelay.onRestoreFocus?()
            }
        )
        let hostingView = ShelfHostingView(rootView: rootView)
        hostingView.sizingOptions = []
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        let container = NSView(frame: .zero)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(hostingView)

        let overlayHost = ShelfOverlayHost(frame: .zero)
        overlayHost.autoresizingMask = [.width, .height]
        overlayHost.wantsLayer = true
        overlayHost.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(overlayHost)

        self.shelfHostingView = hostingView
        self.overlayHost = overlayHost
        self.panel = ClipboardShelfPanel(contentView: container)

        super.init()

        actionRelay.onPreview = { [weak self] item in
            guard let self else { return }
            self.onPreviewItem?(item, self.anchorRect(for: item.id))
        }
        actionRelay.onTranslate = { [weak self] item in
            guard let self else { return }
            self.onTranslateItem?(item, self.anchorRect(for: item.id))
        }
        actionRelay.onMaxScrollOffset = { [weak self] maxOffset in
            guard let self else { return }
            self.maxScrollOffset = maxOffset
            if self.interaction.scrollOffset > maxOffset {
                self.interaction.scrollOffset = maxOffset
            }
        }
        actionRelay.onHideShelf = { [weak self] in
            self?.hide()
        }
        actionRelay.onRestoreFocus = { [weak self] in
            self?.restoreFocusAfterShelfCopy()
        }
        hostingView.onScrollWheel = { [weak self] event in
            self?.handleScrollWheel(event) ?? false
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

    func edgeDidChange() {
        interaction.scrollOffset = 0
        hide()
        if let screen = ClipboardShelfLayout.screenUnderPointer() {
            placePanel(on: screen)
        }
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

    private func handleScrollWheel(_ event: NSEvent) -> Bool {
        guard isRevealed, !isHiding, maxScrollOffset > 0.5 else {
            return false
        }

        let rawDelta: CGFloat
        if edge == .top {
            rawDelta = event.scrollingDeltaX != 0
                ? event.scrollingDeltaX
                : event.scrollingDeltaY
        } else {
            rawDelta = event.scrollingDeltaY
        }

        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
        let delta = rawDelta * multiplier
        guard abs(delta) > 0.01 else { return false }

        let next = min(
            max(interaction.scrollOffset - delta, 0),
            maxScrollOffset
        )
        guard next != interaction.scrollOffset else { return true }
        interaction.scrollOffset = next
        return true
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

            let revealBand = ClipboardShelfLayout.revealBand(
                of: screen,
                edge: edge
            )
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
        if edge == .top, let screen = panel.screen {
            // Extend the zone to the top of the screen so moving up into the
            // menu bar to use a menu does not retract the shelf.
            zone.size.height = screen.frame.maxY - zone.minY
        }

        let inside = NSMouseInRect(mouse, zone, false)

        if isRetractBlocked?() == true {
            awaySince = nil
        } else if inside {
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
        guard isRevealed, !isHiding, !isRevealing else {
            panel.ignoresMouseEvents = true
            interaction.hoveredItemID = nil
            releasePointerCursor()
            return
        }

        let windowPoint = panel.convertPoint(fromScreen: mouse)
        let local = shelfHostingView.convert(windowPoint, from: nil)
        // NSHostingView is flipped (origin at the top-left), which is the
        // same coordinate space used by the SwiftUI hit-target preferences.
        let point = CGPoint(
            x: local.x,
            y: shelfHostingView.isFlipped
                ? local.y
                : shelfHostingView.bounds.height - local.y
        )

        let target = ClipboardShelfLayout.hitTarget(
            at: point,
            in: hitTargetStore.targets
        )

        let detailHit = overlayDetailFrame?.contains(mouse) ?? false

        let hoveredID: UUID?
        if detailHit {
            hoveredID = nil
        } else {
            switch target?.kind {
            case let .card(id), let .cardClip(id), let .cardActions(id):
                hoveredID = id
            case .filterBar, .none:
                hoveredID = nil
            }
        }
        if interaction.hoveredItemID != hoveredID {
            interaction.hoveredItemID = hoveredID
        }

        let wantsPointer = !detailHit && target != nil
        let activatesShelf: Bool
        if !detailHit, let kind = target?.kind {
            switch kind {
            case .cardClip, .cardActions, .filterBar:
                activatesShelf = true
            case .card:
                activatesShelf = false
            }
        } else {
            activatesShelf = false
        }
        let detailVisible = isRetractBlocked?() == true
        if activatesShelf, !detailVisible {
            activateForShelfIfNeeded()
        }
        updatePointerCursor(wantsPointer && !detailVisible)

        let acceptsMouse = target != nil || detailHit
        if panel.ignoresMouseEvents == acceptsMouse {
            panel.ignoresMouseEvents = !acceptsMouse
        }
    }

    /// Liquid Glass uses a subdued material while its app is not active.
    /// Activating the shelf on reveal gives the glass its active appearance
    /// immediately; the previous app is restored when the shelf hides.
    private func activateForGlassIfNeeded() {
        guard #available(macOS 26.0, *),
              settings.liquidGlassEnabled,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
              !NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        else {
            return
        }
        activateForShelfIfNeeded()
    }

    private func activateForShelfIfNeeded() {
        if isRetractBlocked?() == true {
            return
        }
        if let keyWindow = NSApp.keyWindow, keyWindow !== panel {
            return
        }

        guard !NSApp.isActive else {
            panel.makeKey()
            return
        }

        if activationRestoreApp == nil {
            activationRestoreApp = NSWorkspace.shared.frontmostApplication
            if activationRestoreApp?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier {
                activationRestoreApp = nil
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
    }

    private func restoreApplicationAfterShelf() {
        guard let app = activationRestoreApp else { return }
        // Do not steal focus back if the user switched away, or if another
        // HaoPaste window (main panel, translation card) is now key.
        guard NSApp.isActive, NSApp.keyWindow == nil else {
            activationRestoreApp = nil
            return
        }
        activationRestoreApp = nil
        app.activate(options: [])
    }

    /// The glass workaround activates HaoPaste while the shelf is open. If a
    /// card is copied and the shelf stays open, give focus back immediately so
    /// the user can paste into the previous app without an extra click.
    private func restoreFocusAfterShelfCopy() {
        guard settings.shelfCopyBehavior == .stayOpen,
              isRevealed,
              let app = activationRestoreApp else {
            return
        }
        activationRestoreApp = nil
        panel.resignKey()
        app.activate(options: [])
    }

    private func updatePointerCursor(_ wantsPointer: Bool) {
        if wantsPointer {
            if !isPointerHandPushed {
                NSCursor.pointingHand.push()
                isPointerHandPushed = true
            }
            // Re-assert on every tick: the nonactivating panel can have its
            // cursor reset by AppKit cursor rects while the pointer moves.
            NSCursor.pointingHand.set()
        } else if isPointerHandPushed {
            NSCursor.pop()
            isPointerHandPushed = false
        }
    }

    private func releasePointerCursor() {
        guard isPointerHandPushed else { return }
        NSCursor.pop()
        isPointerHandPushed = false
    }

    // MARK: - Reveal / retract

    private func reveal(on screen: NSScreen) {
        guard !isHiding else { return }
        resetOverlayState()

        placePanel(on: screen)
        let target = ClipboardShelfLayout.panelFrame(on: screen, edge: edge)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let start = reduceMotion
            ? target
            : collapsedFrame(from: target)

        panel.alphaValue = 1
        panel.setFrame(start, display: false)
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()

        isRevealed = true
        awaySince = nil
        interaction.hoveredItemID = nil
        interaction.scrollOffset = 0
        startMouseTracking(interval: Timing.visiblePollInterval)

        activateForGlassIfNeeded()

        if reduceMotion {
            isRevealing = false
            refreshGlassSurfaces()
        } else {
            isRevealing = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.8
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.42, 0.02, 0.22, 1.0
                )
                panel.animator().setFrame(target, display: true)
            } completionHandler: { [weak self] in
                guard let self else { return }
                self.isRevealing = false
                self.forcePanelDisplay()
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + Timing.revealGlassRefreshDelay
            ) { [weak self] in
                self?.refreshGlassSurfaces()
            }
        }

        onVisibilityChanged?()
    }

    /// A panel laid out offscreen can keep a stale material rendering of the
    /// glass surfaces. Recreating them once the shelf is on screen makes the
    /// first reveal match the settled appearance without requiring hover.
    private func refreshGlassSurfaces() {
        guard isRevealed, !isHiding else { return }
        interaction.glassRefreshToken &+= 1
        forcePanelDisplay()
    }

    private func forcePanelDisplay() {
        guard isRevealed, !isHiding else { return }
        panel.contentView?.needsLayout = true
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.contentView?.needsDisplay = true
        panel.displayIfNeeded()
    }

    private func hide() {
        guard isRevealed, !isHiding else { return }

        releasePointerCursor()
        onWillHide?()
        resetOverlayState()
        isRevealed = false
        isHiding = true
        isRevealing = false
        interaction.hoveredItemID = nil
        interaction.scrollOffset = 0
        startMouseTracking(interval: Timing.hiddenPollInterval)
        manualOpen = false
        manualVisited = false
        hotZoneSince = nil
        awaySince = nil
        panel.ignoresMouseEvents = true

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        let target = screen.map {
            ClipboardShelfLayout.panelFrame(on: $0, edge: edge)
        } ?? panel.frame
        let end = reduceMotion
            ? target
            : collapsedFrame(from: target)

        let finish = { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            self.panel.setFrame(target, display: false)
            self.isHiding = false
            self.restoreApplicationAfterShelf()
            self.onVisibilityChanged?()
        }

        guard !reduceMotion else {
            finish()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.5, 0.0, 0.75, 0.95
            )
            panel.animator().setFrame(end, display: true)
        } completionHandler: {
            DispatchQueue.main.async(execute: finish)
        }
    }

    private func anchorRect(for itemID: UUID) -> NSRect? {
        let target = hitTargetStore.targets.first(
            where: {
                $0.kind == .card(itemID)
                    && $0.rect.width > 0
                    && $0.rect.height > 0
            }
        ) ?? hitTargetStore.targets.first(
            where: { $0.kind == .cardActions(itemID) }
        ) ?? hitTargetStore.targets.first(
            where: { $0.kind == .cardClip(itemID) }
        )

        guard let target else {
            let mouse = NSEvent.mouseLocation
            return NSRect(origin: mouse, size: .zero)
        }

        let rect = target.rect
        let shelfFrame = shelfScreenFrame
        return NSRect(
            x: shelfFrame.minX + rect.minX,
            y: shelfFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func placePanel(on screen: NSScreen) {
        if shelfFrameWithoutOverlay != nil {
            resetOverlayState()
        }
        let frame = ClipboardShelfLayout.panelFrame(on: screen, edge: edge)
        if panel.frame != frame {
            panel.setFrame(frame, display: false)
        }
        if overlayContentView == nil {
            let bounds = panel.contentView?.bounds
                ?? NSRect(origin: .zero, size: frame.size)
            shelfHostingView.autoresizingMask = []
            shelfHostingView.frame = NSRect(
                origin: .zero,
                size: bounds.size
            )
            overlayHost.autoresizingMask = []
            overlayHost.frame = NSRect(origin: .zero, size: bounds.size)
            shelfHostingView.autoresizingMask = [.width, .height]
            overlayHost.autoresizingMask = [.width, .height]
        }
    }

    /// Where the shelf starts before revealing and ends when hiding.
    /// Every edge slides the whole shelf in as one piece: the top moves down
    /// from above the menu bar, the sides move in from their screen edge.
    private func collapsedFrame(from target: NSRect) -> NSRect {
        let distance = edge == .top
            ? target.height + 24
            : ClipboardShelfLayout.sidePanelWidth + 24
        let slide = ClipboardShelfLayout.slideOffset(
            for: edge,
            distance: distance
        )
        return target.offsetBy(dx: slide.width, dy: slide.height)
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
    var onTranslate: ((ClipboardItem) -> Void)?
    var onMaxScrollOffset: ((CGFloat) -> Void)?
    var onHideShelf: (() -> Void)?
    var onRestoreFocus: (() -> Void)?
}

/// The shelf is shown while another app is active, so the first click must
/// reach the card instead of being consumed by window activation.
/// The shelf is shown while another app can still be active, so the detail
/// hosting view must accept the first click just like the shelf cards do.
private final class ShelfOverlayHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

/// Transparent host for shelf detail content. Returning nil when no child is
/// hit lets clicks fall through to the shelf or the desktop.
private final class ShelfOverlayHost: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let superview else { return nil }
        // `point` is in the superview's coordinates. The subview hit test
        // expects a point in this host's coordinates.
        let local = convert(point, from: superview)
        return subviews.reversed().lazy.compactMap { $0.hitTest(local) }.first
    }
}

private final class ShelfHostingView<Content: View>: NSHostingView<Content> {
    var onScrollWheel: ((NSEvent) -> Bool)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func scrollWheel(with event: NSEvent) {
        if onScrollWheel?(event) == true {
            return
        }
        super.scrollWheel(with: event)
    }
}
