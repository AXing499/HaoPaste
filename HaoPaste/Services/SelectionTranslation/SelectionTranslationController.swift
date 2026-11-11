//
//  SelectionTranslationController.swift
//  HaoPaste
//
//  Optional global selection translation. Reads the focused app's selected
//  text through Accessibility and never synthesizes ⌘C.
//

import AppKit
import SwiftUI

@MainActor
final class SelectionTranslationController: NSObject, NSWindowDelegate {
    private let manager: ClipboardManager
    private let snippetManager: SnippetManager
    private let service: TranslationService
    private let settings: AppSettings

    private let iconPanel: SelectionTranslationIconPanel
    private let cardPanel: SelectionTranslationCardPanel
    private let iconButton: SelectionTranslationIconButton

    private let iconSize: CGFloat = 34
    private let iconButtonSize: CGFloat = 28
    private let cardSize = NSSize(width: 400, height: 340)

    private var isEnabled = false
    private var mouseUpMonitor: Any?
    private var dismissMonitor: Any?
    private var keyMonitor: Any?
    private var cardKeyMonitor: Any?
    private var selectionCheckTask: Task<Void, Never>?
    private var iconHideTask: Task<Void, Never>?
    private var iconGeneration = 0
    private var workspaceObserver: NSObjectProtocol?
    private var applicationObserver: NSObjectProtocol?

    private var selectedText = ""
    private var sourceTitle = ""
    private var selectionSourceApp: NSRunningApplication?
    private var selectionAnchor = NSPoint.zero
    private var previousApplication: NSRunningApplication?
    private var isHidingCard = false

    init(
        manager: ClipboardManager,
        snippetManager: SnippetManager,
        service: TranslationService,
        settings: AppSettings
    ) {
        self.manager = manager
        self.snippetManager = snippetManager
        self.service = service
        self.settings = settings
        self.iconPanel = SelectionTranslationIconPanel(
            contentRect: NSRect(x: 0, y: 0, width: 34, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.cardPanel = SelectionTranslationCardPanel(
            contentRect: NSRect(origin: .zero, size: cardSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.iconButton = SelectionTranslationIconButton()
        super.init()

        configureIconPanel()
        configureCardPanel()
        installIconContent()
        installCardContent()

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let app = notification.userInfo?[
                    NSWorkspace.applicationUserInfoKey
                ] as? NSRunningApplication
                if app?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                    self.hideIcon()
                }
                self.accessibilityDidChange()
            }
        }

        applicationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hideIcon()
                self?.accessibilityDidChange()
            }
        }
    }

    deinit {
        if let mouseUpMonitor {
            NSEvent.removeMonitor(mouseUpMonitor)
        }
        if let dismissMonitor {
            NSEvent.removeMonitor(dismissMonitor)
        }
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let cardKeyMonitor {
            NSEvent.removeMonitor(cardKeyMonitor)
        }
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        if let applicationObserver {
            NotificationCenter.default.removeObserver(applicationObserver)
        }
    }

    // MARK: - Enablement

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled

        guard enabled else {
            stopMonitoring()
            hideIcon()
            hideCard()
            return
        }

        if SelectionTranslationAccess.isTrusted {
            startMonitoring()
        } else {
            stopMonitoring()
            hideIcon()
        }
    }

    private func accessibilityDidChange() {
        guard isEnabled else { return }
        if SelectionTranslationAccess.isTrusted {
            startMonitoring()
        } else {
            stopMonitoring()
            hideIcon()
        }
    }

    private func startMonitoring() {
        guard mouseUpMonitor == nil else { return }

        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseUp]
        ) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseUp(event)
            }
        }

        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissForOutsideInteraction()
            }
        }

        keyMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissForOutsideInteraction()
            }
        }
    }

    private func stopMonitoring() {
        for monitor in [mouseUpMonitor, dismissMonitor, keyMonitor] {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        mouseUpMonitor = nil
        dismissMonitor = nil
        keyMonitor = nil
        cancelSelectionCheck()
    }

    private func dismissForOutsideInteraction() {
        cancelSelectionCheck()
        hideIcon()
    }

    // MARK: - Selection detection

    private func handleMouseUp(_ event: NSEvent) {
        guard
            isEnabled,
            SelectionTranslationAccess.isTrusted,
            !SelectionTextReader.isSecureInputEnabled(),
            !cardPanel.isVisible,
            let app = NSWorkspace.shared.frontmostApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return
        }

        let source = SourceApplication(
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? ""
        )
        guard !settings.isSourceExcluded(source) else { return }
        guard !SelectionTextReader.isFullscreen(app) else { return }

        let anchor = NSEvent.mouseLocation
        guard let screen = screen(containing: anchor) else { return }
        guard screen.visibleFrame.contains(anchor) else { return }

        cancelSelectionCheck()
        selectionCheckTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.readSelection(from: app, anchor: anchor)
            }
        }
    }

    private func readSelection(
        from app: NSRunningApplication,
        anchor: NSPoint
    ) {
        guard
            isEnabled,
            SelectionTranslationAccess.isTrusted,
            NSWorkspace.shared.frontmostApplication?.processIdentifier
                == app.processIdentifier,
            let text = SelectionTextReader.selectedText(in: app)
        else {
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        selectedText = text
        sourceTitle = app.localizedName ?? L("划词翻译")
        selectionSourceApp = app
        selectionAnchor = anchor

        showIcon(at: anchor)
    }

    private func cancelSelectionCheck() {
        selectionCheckTask?.cancel()
        selectionCheckTask = nil
    }

    // MARK: - Icon

    private func showIcon(at anchor: NSPoint) {
        guard let screen = screen(containing: anchor) else { return }

        iconGeneration &+= 1
        iconPanel.setFrame(
            SelectionTranslationLayout.iconFrame(
                anchor: anchor,
                size: iconSize,
                visibleFrame: screen.visibleFrame
            ),
            display: false
        )

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        iconPanel.alphaValue = reduceMotion ? 1 : 0
        iconButton.layer?.setAffineTransform(
            reduceMotion
                ? .identity
                : CGAffineTransform(scaleX: 0.78, y: 0.78)
        )
        iconPanel.orderFrontRegardless()

        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.16, 1, 0.3, 1
                )
                iconPanel.animator().alphaValue = 1
            }
            animateIconScale(
                from: 0.78,
                to: 1,
                stiffness: 300,
                damping: 24,
                duration: 0.34
            )
        }

        iconHideTask?.cancel()
        iconHideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2600))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.hideIcon()
            }
        }
    }

    private func hideIcon() {
        iconHideTask?.cancel()
        iconHideTask = nil

        guard iconPanel.isVisible else { return }

        iconGeneration &+= 1
        let generation = iconGeneration
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        guard !reduceMotion else {
            iconPanel.orderOut(nil)
            iconPanel.alphaValue = 1
            iconButton.layer?.setAffineTransform(.identity)
            return
        }

        animateIconScale(
            from: 1,
            to: 0.88,
            stiffness: 260,
            damping: 30,
            duration: 0.12
        )
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            iconPanel.animator().alphaValue = 0
        } completionHandler: {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.iconGeneration == generation else { return }
                self.iconPanel.orderOut(nil)
                self.iconPanel.alphaValue = 1
                self.iconButton.layer?.setAffineTransform(.identity)
            }
        }
    }

    private func animateIconScale(
        from: CGFloat,
        to: CGFloat,
        stiffness: CGFloat,
        damping: CGFloat,
        duration: CFTimeInterval
    ) {
        guard let layer = iconButton.layer else { return }

        layer.setAffineTransform(CGAffineTransform(scaleX: to, y: to))
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.fromValue = from
        animation.toValue = to
        animation.mass = 1
        animation.stiffness = stiffness
        animation.damping = damping
        animation.initialVelocity = 0
        animation.duration = duration
        layer.add(animation, forKey: "selectionIconScale")
    }

    @objc
    private func translateSelection() {
        guard !selectedText.isEmpty else { return }
        hideIcon()
        cancelSelectionCheck()

        previousApplication = selectionSourceApp
            ?? NSWorkspace.shared.frontmostApplication

        service.present(text: selectedText, title: sourceTitle)
        showCard()
    }

    // MARK: - Card

    private func showCard() {
        guard let screen = screen(containing: selectionAnchor) else { return }

        let target = SelectionTranslationLayout.cardFrame(
            anchor: selectionAnchor,
            size: cardSize,
            visibleFrame: screen.visibleFrame
        )
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        cardPanel.alphaValue = reduceMotion ? 1 : 0
        cardPanel.setFrame(
            reduceMotion ? target : target.offsetBy(dx: 0, dy: -8),
            display: false
        )

        NSApp.activate()
        cardPanel.makeKeyAndOrderFront(nil)
        cardPanel.orderFrontRegardless()
        installCardKeyMonitor()

        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.16, 1, 0.3, 1
                )
                cardPanel.animator().alphaValue = 1
                cardPanel.animator().setFrame(target, display: true)
            }
        }
    }

    func hideCard(restoreFocus: Bool = true) {
        guard cardPanel.isVisible, !isHidingCard else { return }

        isHidingCard = true
        service.close()
        removeCardKeyMonitor()

        if !restoreFocus {
            previousApplication = nil
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let finish = { [weak self] in
            guard let self else { return }
            self.isHidingCard = false
            self.cardPanel.orderOut(nil)
            self.cardPanel.alphaValue = 1

            if let application = self.previousApplication,
               !application.isTerminated,
               application.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                application.activate(options: [])
            }
            self.previousApplication = nil
        }

        guard !reduceMotion else {
            finish()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cardPanel.animator().alphaValue = 0
        } completionHandler: {
            DispatchQueue.main.async(execute: finish)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSPanel === cardPanel else { return }
        hideCard(restoreFocus: false)
    }

    private func installCardKeyMonitor() {
        removeCardKeyMonitor()

        cardKeyMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            guard
                let self,
                self.cardPanel.isVisible,
                self.cardPanel.isKeyWindow
            else {
                return event
            }

            let flags = event.modifierFlags.intersection([
                .command, .option, .control, .shift
            ])

            if event.keyCode == 53 { // escape
                self.hideCard()
                return nil
            }
            if flags == .command, event.keyCode == 8 { // C
                self.copyTranslation()
                return nil
            }
            if flags == .command, event.keyCode == 13 { // W
                self.hideCard()
                return nil
            }
            return event
        }
    }

    private func removeCardKeyMonitor() {
        if let cardKeyMonitor {
            NSEvent.removeMonitor(cardKeyMonitor)
            self.cardKeyMonitor = nil
        }
    }

    // MARK: - Actions

    private func copyTranslation() {
        guard !service.resultText.isEmpty else {
            NSSound.beep()
            return
        }
        guard manager.copyTextToPasteboard(service.resultText) else { return }
        hideCard()
    }

    private func copyBilingual() {
        guard !service.resultText.isEmpty else {
            NSSound.beep()
            return
        }
        let text = L(
            "原文：\n%@\n\n译文：\n%@",
            service.sourceText,
            service.resultText
        )
        guard manager.copyTextToPasteboard(text) else { return }
        hideCard()
    }

    private func saveSnippet() {
        guard !service.resultText.isEmpty else {
            NSSound.beep()
            return
        }
        let title = service.sourceTitle.count > 20
            ? String(service.sourceTitle.prefix(20)) + "…"
            : service.sourceTitle
        _ = snippetManager.create(
            title: L("翻译 · %@", title),
            content: service.resultText
        )
    }

    private func openTranslationSettings() {
        hideCard(restoreFocus: false)
        NotificationCenter.default.post(
            name: .haopasteOpenTranslationSettings,
            object: nil
        )
    }

    // MARK: - Panels

    private func configureIconPanel() {
        iconPanel.isFloatingPanel = true
        iconPanel.level = .floating
        iconPanel.backgroundColor = .clear
        iconPanel.isOpaque = false
        iconPanel.hasShadow = false
        iconPanel.hidesOnDeactivate = false
        iconPanel.becomesKeyOnlyIfNeeded = true
        iconPanel.isMovableByWindowBackground = false
        iconPanel.isReleasedWhenClosed = false
        iconPanel.animationBehavior = .none
        iconPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .transient,
            .ignoresCycle
        ]
    }

    private func configureCardPanel() {
        cardPanel.isFloatingPanel = true
        cardPanel.level = .floating
        cardPanel.backgroundColor = .clear
        cardPanel.isOpaque = false
        cardPanel.hasShadow = false
        cardPanel.hidesOnDeactivate = false
        cardPanel.becomesKeyOnlyIfNeeded = false
        cardPanel.isMovableByWindowBackground = false
        cardPanel.isReleasedWhenClosed = false
        cardPanel.animationBehavior = .none
        cardPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        cardPanel.delegate = self
    }

    private func installIconContent() {
        iconButton.target = self
        iconButton.action = #selector(translateSelection)
        iconButton.isBordered = false
        iconButton.toolTip = L("翻译选中文本")
        iconButton.setAccessibilityLabel(L("翻译选中文本"))
        iconButton.focusRingType = .none
        iconButton.frame = NSRect(
            x: (iconSize - iconButtonSize) / 2,
            y: (iconSize - iconButtonSize) / 2,
            width: iconButtonSize,
            height: iconButtonSize
        )
        iconButton.autoresizingMask = [
            .minXMargin,
            .maxXMargin,
            .minYMargin,
            .maxYMargin
        ]
        iconButton.wantsLayer = true
        iconButton.layer?.backgroundColor = NSColor.clear.cgColor
        iconButton.layer?.borderWidth = 0
        iconButton.layer?.shadowOpacity = 0

        let container = NSView(
            frame: NSRect(x: 0, y: 0, width: iconSize, height: iconSize)
        )
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(iconButton)
        iconPanel.contentView = container
    }

    private func installCardContent() {
        let rootView = SelectionTranslationCardView(
            service: service,
            onCopyTranslation: { [weak self] in
                self?.copyTranslation()
            },
            onCopyBilingual: { [weak self] in
                self?.copyBilingual()
            },
            onSaveSnippet: { [weak self] in
                self?.saveSnippet()
            },
            onClose: { [weak self] in
                self?.hideCard()
            },
            onOpenSettings: { [weak self] in
                self?.openTranslationSettings()
            }
        )
        .frame(width: cardSize.width, height: cardSize.height)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: cardSize)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        cardPanel.contentView = hostingView
    }

    // MARK: - Helpers

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

private final class SelectionTranslationIconButton: NSButton {
    private var isHovering = false
    private var isPressed = false
    private var trackingArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let symbol = NSImage(
            systemSymbolName: "translate",
            accessibilityDescription: nil
        ) else {
            return
        }

        let pointSize: CGFloat = isHovering || isPressed ? 14.2 : 13.5
        let configuration = NSImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: .semibold
        )
        let configured = symbol.withSymbolConfiguration(configuration) ?? symbol
        let glyphSize = configured.size
        let glyphRect = NSRect(
            x: bounds.midX - glyphSize.width / 2,
            y: bounds.midY - glyphSize.height / 2,
            width: glyphSize.width,
            height: glyphSize.height
        )

        let tint = isHovering || isPressed
            ? NSColor.controlAccentColor
            : NSColor.labelColor
        let tinted = NSImage(size: glyphSize, flipped: false) { rect in
            configured.draw(in: rect)
            tint.set()
            rect.fill(using: .sourceAtop)
            return true
        }

        // A soft contrasting halo keeps the bare glyph legible over both light
        // and dark page content without adding a visible circle or border.
        let isDark = effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        ) == .darkAqua
        let halo = NSShadow()
        halo.shadowColor = isDark
            ? NSColor.black.withAlphaComponent(0.55)
            : NSColor.white.withAlphaComponent(0.92)
        halo.shadowBlurRadius = isHovering ? 3.2 : 2.6
        halo.shadowOffset = .zero

        NSGraphicsContext.saveGraphicsState()
        halo.set()
        tinted.draw(in: glyphRect)
        NSGraphicsContext.restoreGraphicsState()
        tinted.draw(in: glyphRect)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        updateAppearance()
        super.mouseDown(with: event)
        isPressed = false
        updateAppearance()
    }

    private func updateAppearance() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let target: CGFloat = isPressed ? 0.92 : (isHovering ? 1.06 : 1)

        if reduceMotion || window?.isVisible != true {
            layer?.setAffineTransform(
                CGAffineTransform(scaleX: target, y: target)
            )
        } else {
            let currentScale = (
                (
                    layer?.presentation()?.value(forKeyPath: "transform.scale")
                        ?? layer?.value(forKeyPath: "transform.scale")
                ) as? NSNumber
            )?.doubleValue ?? 1

            layer?.setAffineTransform(
                CGAffineTransform(scaleX: target, y: target)
            )
            let animation = CASpringAnimation(keyPath: "transform.scale")
            animation.fromValue = currentScale
            animation.toValue = target
            animation.mass = 1
            animation.stiffness = 340
            animation.damping = 26
            animation.initialVelocity = 0
            animation.duration = 0.26
            layer?.add(animation, forKey: "selectionIconScale")
        }

        needsDisplay = true
    }
}

private final class SelectionTranslationIconPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class SelectionTranslationCardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
