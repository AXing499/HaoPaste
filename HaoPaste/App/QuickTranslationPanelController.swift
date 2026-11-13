//
//  QuickTranslationPanelController.swift
//  HaoPaste
//
//  Compact floating translation card for the global "translate clipboard" shortcut.
//

import AppKit
import SwiftUI

@MainActor
final class QuickTranslationPanelController: NSObject, NSWindowDelegate {
    private let manager: ClipboardManager
    private let service: TranslationService
    private let snippetManager: SnippetManager

    private let panel: QuickTranslationPanel

    var isVisible: Bool {
        panel.isVisible
    }

    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var deactivationObserver: NSObjectProtocol?
    private var previousApplication: NSRunningApplication?
    private var isHiding = false

    enum PresentationSource {
        case hotKey
        case shelf
    }

    var onWillPresent: ((PresentationSource) -> Void)?

    private(set) var presentationSource: PresentationSource = .hotKey

    var isVisibleFromShelf: Bool {
        panel.isVisible && presentationSource == .shelf
    }

    private let cardSize = NSSize(width: 640, height: 480)
    private let windowSize = NSSize(width: 640, height: 480)

    init(
        manager: ClipboardManager,
        service: TranslationService,
        snippetManager: SnippetManager
    ) {
        self.manager = manager
        self.service = service
        self.snippetManager = snippetManager
        self.panel = QuickTranslationPanel(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init()

        configurePanel()
        installContent()
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let deactivationObserver {
            NotificationCenter.default.removeObserver(deactivationObserver)
        }
    }

    // MARK: - Presentation

    func translateClipboard() {
        guard let text = ClipboardTranslationReader.text(
            from: NSPasteboard.general
        ) else {
            NSSound.beep()
            return
        }

        if panel.isVisible {
            show(
                text: text,
                title: L("剪贴板翻译"),
                anchor: nil,
                edge: nil,
                source: .hotKey,
                animated: false
            )
        } else {
            show(
                text: text,
                title: L("剪贴板翻译"),
                anchor: nil,
                edge: nil,
                source: .hotKey,
                animated: true
            )
        }
    }

    func translate(
        text: String,
        title: String,
        anchor: NSRect,
        edge: ClipboardShelfEdge,
        keepShelfKey: Bool = false
    ) {
        show(
            text: text,
            title: title,
            anchor: anchor,
            edge: edge,
            source: .shelf,
            animated: true,
            keepShelfKey: keepShelfKey
        )
    }

    /// Presents a centered translation card for a screenshot OCR result.
    func present(text: String, title: String) {
        show(
            text: text,
            title: title,
            anchor: nil,
            edge: nil,
            source: .hotKey,
            animated: true
        )
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            translateClipboard()
        }
    }

    private func show(
        text: String,
        title: String,
        anchor: NSRect?,
        edge: ClipboardShelfEdge?,
        source: PresentationSource,
        animated: Bool,
        keepShelfKey: Bool = false
    ) {
        panel.allowsKey = !keepShelfKey
        onWillPresent?(source)
        presentationSource = source

        if previousApplication == nil || !panel.isVisible {
            previousApplication = NSWorkspace.shared.frontmostApplication
            if previousApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
                previousApplication = nil
            }
        }

        let target: NSRect
        if let anchor, let edge {
            target = ClipboardShelfLayout.centeredDetailFrame(
                size: windowSize,
                anchor: anchor
            )
        } else {
            target = targetFrame()
        }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        panel.alphaValue = animated && !reduceMotion ? 0 : 1
        panel.setFrame(
            animated && !reduceMotion
                ? target.offsetBy(dx: 0, dy: 8)
                : target,
            display: false
        )

        service.present(text: text, title: title)
        if keepShelfKey {
            panel.orderFrontRegardless()
        } else {
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
        }

        installKeyMonitor()
        installMouseMonitor()
        installGlobalMouseMonitor()
        installDeactivationObserver()

        if animated && !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.16, 1, 0.3, 1
                )
                panel.animator().alphaValue = 1
                panel.animator().setFrame(target, display: true)
            }
        }
    }

    func hide() {
        guard panel.isVisible, !isHiding else { return }

        isHiding = true
        service.close()
        removeMonitors()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let finish = { [weak self] in
            guard let self else { return }
            self.isHiding = false
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            self.presentationSource = .hotKey

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
            panel.animator().alphaValue = 0
        } completionHandler: {
            DispatchQueue.main.async(execute: finish)
        }
    }

    // MARK: - Key handling

    private func installKeyMonitor() {
        removeKeyMonitor()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                self.panel.isVisible,
                self.panel.isKeyWindow
            else {
                return event
            }
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let isCommandOnly = flags == .command

        if event.keyCode == 53 { // escape
            hide()
            return true
        }

        if (event.keyCode == 36 || event.keyCode == 76), flags.isEmpty {
            copyTranslationAndHide()
            return true
        }

        if isCommandOnly, event.keyCode == 8 { // C
            copyTranslationAndHide()
            return true
        }

        if isCommandOnly, event.keyCode == 15 { // R
            service.retry()
            return true
        }

        if isCommandOnly, event.keyCode == 13 { // W
            hide()
            return true
        }

        // The quick card has no text editor; keep the keys from falling through
        // to whatever window was active before.
        return true
    }

    private func copyTranslationAndHide() {
        guard !service.resultText.isEmpty else {
            NSSound.beep()
            return
        }

        guard manager.copyTextToPasteboard(service.resultText) else { return }
        hide()
    }

    private func copyBilingualAndHide() {
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
        hide()
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

    // MARK: - Mouse / deactivation

    private func installMouseMonitor() {
        removeMouseMonitor()

        mouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard
                let self,
                self.panel.isVisible,
                event.window === self.panel
            else {
                return event
            }

            let cardRect = NSRect(
                origin: NSPoint(
                    x: (self.windowSize.width - self.cardSize.width) / 2,
                    y: (self.windowSize.height - self.cardSize.height) / 2
                ),
                size: self.cardSize
            )

            if !cardRect.contains(event.locationInWindow) {
                self.hide()
                return nil
            }

            return event
        }
    }

    private func removeMouseMonitor() {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
    }

    private func installGlobalMouseMonitor() {
        removeGlobalMouseMonitor()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.panel.isVisible, !self.isHiding else { return }
                self.hide()
            }
        }
    }

    private func removeGlobalMouseMonitor() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func installDeactivationObserver() {
        removeDeactivationObserver()

        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.panel.isVisible, !self.isHiding else { return }
                self.hide()
            }
        }
    }

    private func removeDeactivationObserver() {
        if let deactivationObserver {
            NotificationCenter.default.removeObserver(deactivationObserver)
            self.deactivationObserver = nil
        }
    }

    private func removeMonitors() {
        removeKeyMonitor()
        removeMouseMonitor()
        removeGlobalMouseMonitor()
        removeDeactivationObserver()
    }

    // MARK: - Window

    private func configurePanel() {
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
        panel.delegate = self
    }

    private func installContent() {
        let rootView = TranslationPaneView(
            service: service,
            onCopyTranslation: { [weak self] text in
                self?.copyTextAndHide(text)
            },
            onCopyBilingual: { [weak self] _ in
                self?.copyBilingualAndHide()
            },
            onSaveSnippet: { [weak self] _ in
                self?.saveSnippet()
            },
            onClose: { [weak self] in
                self?.hide()
            },
            showsScrim: false,
            onOpenSettings: { [weak self] in
                self?.hide()
                NotificationCenter.default.post(
                    name: .haopasteOpenTranslationSettings,
                    object: nil
                )
            }
        )
        .frame(width: windowSize.width, height: windowSize.height)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: windowSize)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentView = hostingView
    }

    private func copyTextAndHide(_ text: String) {
        guard !text.isEmpty, manager.copyTextToPasteboard(text) else { return }
        hide()
    }

    private func targetFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else {
            return NSRect(origin: .zero, size: windowSize)
        }

        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - windowSize.width / 2
        let y = visibleFrame.maxY - windowSize.height - 48

        return NSRect(
            x: x.rounded(.down),
            y: max(y, visibleFrame.minY + 20).rounded(.down),
            width: windowSize.width,
            height: windowSize.height
        )
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

private final class QuickTranslationPanel: NSPanel {
    var allowsKey = true

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }
}
