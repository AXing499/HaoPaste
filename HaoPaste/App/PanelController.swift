//
//  PanelController.swift
//  HaoPaste
//
//  Owns the borderless floating NSPanel, keyboard navigation and focus restore.
//

import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private enum KeyCode {
        static let a: UInt16 = 0
        static let escape: UInt16 = 53
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let upArrow: UInt16 = 126
        static let downArrow: UInt16 = 125
        static let c: UInt16 = 8
        static let p: UInt16 = 35
        static let w: UInt16 = 13
        static let y: UInt16 = 16
    }

    let manager: ClipboardManager
    let snippetManager: SnippetManager
    let state = PanelViewState()

    private let panel: ClipboardPanel
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var deactivationObserver: NSObjectProtocol?
    private var previousApplication: NSRunningApplication?
    private var presentationGeneration = 0
    private var isHiding = false

    init(manager: ClipboardManager, snippetManager: SnippetManager) {
        self.manager = manager
        self.snippetManager = snippetManager
        self.panel = ClipboardPanel(
            contentRect: NSRect(origin: .zero, size: Theme.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init()

        configurePanel()
        installContent()
        observeApplicationDeactivation()
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

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        presentationGeneration &+= 1
        isHiding = false

        if panel.isVisible {
            panel.alphaValue = 1
            panel.setFrame(targetFrame(), display: true)
            activatePanel()
            return
        }

        previousApplication = NSWorkspace.shared.frontmostApplication
        if previousApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            previousApplication = nil
        }

        let firstItemID = manager.filteredItems(query: "", filter: .all).first?.id
        state.prepareForPresentation(firstItemID: firstItemID)

        let target = targetFrame()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        panel.alphaValue = reduceMotion ? 1 : 0
        panel.setFrame(
            reduceMotion ? target : target.offsetBy(dx: 0, dy: 10),
            display: false
        )

        activatePanel()

        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.16, 1, 0.3, 1
                )
                panel.animator().alphaValue = 1
                panel.animator().setFrame(target, display: true)
            }
        }
    }

    func hide(restoreFocus: Bool = true) {
        guard panel.isVisible, !isHiding else { return }

        isHiding = true
        state.endPreview()
        presentationGeneration &+= 1
        let generation = presentationGeneration

        removeKeyMonitor()
        removeMouseMonitor()
        removeGlobalMouseMonitor()

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        let finish = { [weak self] in
            guard let self else { return }
            self.isHiding = false
            guard self.presentationGeneration == generation else { return }

            self.panel.orderOut(nil)
            self.panel.alphaValue = 1

            if restoreFocus {
                self.restorePreviousApplication()
            } else {
                self.previousApplication = nil
            }
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

    // MARK: - Copying

    func copyAndHide(_ item: ClipboardItem) {
        guard manager.copyToPasteboard(item) else { return }
        hide()
    }

    func copyTextAndHide(_ text: String) {
        guard manager.copyTextToPasteboard(text) else { return }
        hide()
    }

    func copyMergedAndHide(_ items: [ClipboardItem]) {
        guard manager.copyMergedToPasteboard(items) else { return }
        hide()
    }

    func copySnippetAndHide(_ snippet: Snippet) {
        guard manager.copyTextToPasteboard(snippet.content) else { return }
        hide()
    }

    // MARK: - Keyboard

    private var isSnippetMode: Bool {
        state.filter == .snippets
    }

    private var currentVisibleItems: [ClipboardItem] {
        guard !isSnippetMode else { return [] }
        return manager.filteredItems(query: state.searchText, filter: state.filter)
    }

    private var currentVisibleSnippets: [Snippet] {
        guard isSnippetMode else { return [] }
        return snippetManager.filtered(query: state.searchText)
    }

    private func installKeyMonitor() {
        removeKeyMonitor()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible, self.panel.isKeyWindow else {
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

            // Clicks in the transparent shadow padding belong to our window but
            // are visually outside the panel. Treat them as outside clicks.
            let cardRect = NSRect(
                origin: NSPoint(x: Theme.windowPadding, y: Theme.windowPadding),
                size: Theme.panelSize
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

    /// Dismiss when the user clicks into any other application, even if the
    /// panel never managed to become the active application's key window.
    private func installGlobalMouseMonitor() {
        removeGlobalMouseMonitor()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.panel.isVisible, !self.isHiding else { return }
                self.hide(restoreFocus: false)
            }
        }
    }

    private func removeGlobalMouseMonitor() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func observeApplicationDeactivation() {
        deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.panel.isVisible, !self.isHiding else { return }
                self.hide(restoreFocus: false)
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let isCommandOnly = flags == .command

        if state.isPreviewing {
            return handlePreviewKeyDown(
                event,
                flags: flags,
                isCommandOnly: isCommandOnly
            )
        }

        if event.keyCode == KeyCode.escape {
            if !isSnippetMode, state.clearMultiSelection() {
                return true
            }

            if !state.searchText.isEmpty {
                state.searchText = ""
                if isSnippetMode {
                    state.ensureSnippetSelection(in: currentVisibleSnippets)
                } else {
                    state.ensureSelection(in: currentVisibleItems)
                }
                state.requestSearchFocus()
            } else {
                hide()
            }
            return true
        }

        if flags == [.command, .shift], event.keyCode == KeyCode.a {
            if !isSnippetMode {
                state.selectAll(in: currentVisibleItems)
            }
            return true
        }

        if event.keyCode == KeyCode.upArrow, !isCommandOnly {
            if isSnippetMode {
                state.moveSnippetSelection(in: currentVisibleSnippets, by: -1)
            } else {
                state.moveSelection(
                    in: currentVisibleItems,
                    by: -1,
                    extending: flags.contains(.shift)
                )
            }
            return true
        }

        if event.keyCode == KeyCode.downArrow, !isCommandOnly {
            if isSnippetMode {
                state.moveSnippetSelection(in: currentVisibleSnippets, by: 1)
            } else {
                state.moveSelection(
                    in: currentVisibleItems,
                    by: 1,
                    extending: flags.contains(.shift)
                )
            }
            return true
        }

        if (event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.keypadEnter) && flags.isEmpty {
            copySelectedEntry()
            return true
        }

        if isCommandOnly, event.keyCode == KeyCode.p {
            if !isSnippetMode {
                togglePinForSelectedItem()
            }
            return true
        }

        if isCommandOnly, event.keyCode == KeyCode.y {
            if !isSnippetMode, let item = state.selectedItem(in: currentVisibleItems) {
                state.togglePreview(item)
            }
            return true
        }

        if isCommandOnly, [KeyCode.delete, KeyCode.forwardDelete].contains(event.keyCode) {
            if !isSnippetMode {
                deleteSelectedItem()
            }
            return true
        }

        if isCommandOnly, event.keyCode == KeyCode.w {
            hide()
            return true
        }

        if isCommandOnly,
           let characters = event.charactersIgnoringModifiers,
           characters.count == 1,
           let digit = Int(characters),
           (1...9).contains(digit) {
            copyItem(at: digit - 1)
            return true
        }

        return false
    }

    private func handlePreviewKeyDown(
        _ event: NSEvent,
        flags: NSEvent.ModifierFlags,
        isCommandOnly: Bool
    ) -> Bool {
        if event.keyCode == KeyCode.escape {
            state.endPreview()
            return true
        }

        if (event.keyCode == KeyCode.returnKey || event.keyCode == KeyCode.keypadEnter),
           flags.isEmpty {
            copyPreviewedItem()
            return true
        }

        if isCommandOnly, (event.keyCode == KeyCode.y || event.keyCode == KeyCode.c) {
            if event.keyCode == KeyCode.y {
                state.endPreview()
            } else {
                copyPreviewedItem()
            }
            return true
        }

        if !isCommandOnly, event.keyCode == KeyCode.upArrow {
            movePreviewSelection(by: -1)
            return true
        }

        if !isCommandOnly, event.keyCode == KeyCode.downArrow {
            movePreviewSelection(by: 1)
            return true
        }

        // Other command shortcuts target the list underneath; ignore them
        // while the preview is on screen. Plain typing still reaches the search
        // field and closes the preview through ContentView's observer.
        return isCommandOnly
    }

    private func movePreviewSelection(by delta: Int) {
        let items = currentVisibleItems
        guard !items.isEmpty else {
            state.endPreview()
            return
        }

        state.moveSelection(in: items, by: delta)
        state.previewingItemID = state.selectedID
    }

    private func copyPreviewedItem() {
        guard
            let id = state.previewingItemID,
            let item = manager.items.first(where: { $0.id == id })
        else {
            return
        }

        copyAndHide(item)
    }

    private func copySelectedEntry() {
        if isSnippetMode {
            guard
                let snippet = state.selectedSnippet(in: currentVisibleSnippets)
                    ?? currentVisibleSnippets.first
            else {
                return
            }
            copySnippetAndHide(snippet)
        } else if state.isMultiSelecting {
            let selectedItems = state.selectedItems(in: currentVisibleItems)
            guard selectedItems.count > 1 else {
                copySelectedItem()
                return
            }
            copyMergedAndHide(selectedItems)
        } else {
            copySelectedItem()
        }
    }

    private func copySelectedItem() {
        let items = currentVisibleItems
        guard let item = state.selectedItem(in: items) ?? items.first else { return }
        copyAndHide(item)
    }

    private func copyItem(at index: Int) {
        if isSnippetMode {
            let snippets = currentVisibleSnippets
            guard snippets.indices.contains(index) else { return }
            copySnippetAndHide(snippets[index])
        } else {
            let items = currentVisibleItems
            guard items.indices.contains(index) else { return }
            copyAndHide(items[index])
        }
    }

    private func togglePinForSelectedItem() {
        guard let item = state.selectedItem(in: currentVisibleItems) else { return }
        manager.togglePin(item)
        state.ensureSelection(in: currentVisibleItems)
    }

    private func deleteSelectedItem() {
        let items = currentVisibleItems
        guard
            let item = state.selectedItem(in: items),
            let index = items.firstIndex(where: { $0.id == item.id })
        else {
            return
        }

        var fallbackID: UUID?
        if index + 1 < items.count {
            fallbackID = items[index + 1].id
        } else if index > 0 {
            fallbackID = items[index - 1].id
        }

        manager.delete(item)

        let remaining = currentVisibleItems
        if let fallbackID, remaining.contains(where: { $0.id == fallbackID }) {
            state.selectedID = fallbackID
        } else {
            state.ensureSelection(in: remaining)
        }
    }

    // MARK: - Focus

    private func activatePanel() {
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        installKeyMonitor()
        installMouseMonitor()
        installGlobalMouseMonitor()

        // Let the window become key before handing focus to the search field.
        DispatchQueue.main.async { [weak self] in
            self?.state.requestSearchFocus()
        }
    }

    private func restorePreviousApplication() {
        guard let application = previousApplication, !application.isTerminated else {
            previousApplication = nil
            return
        }

        previousApplication = nil

        guard application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }

        application.activate(options: [])
    }

    // MARK: - Window

    private func configurePanel() {
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
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
        let rootView = ContentView(
            state: state,
            onCopy: { [weak self] item in
                self?.copyAndHide(item)
            },
            onCopyMerged: { [weak self] items in
                self?.copyMergedAndHide(items)
            },
            onCopyText: { [weak self] text in
                self?.copyTextAndHide(text)
            },
            onCopySnippet: { [weak self] snippet in
                self?.copySnippetAndHide(snippet)
            }
        )
        .environment(manager)
        .environment(snippetManager)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: Theme.windowSize)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentView = hostingView
    }

    private func targetFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else {
            return NSRect(origin: .zero, size: Theme.windowSize)
        }

        let visibleFrame = screen.visibleFrame
        let size = Theme.windowSize
        let x = visibleFrame.midX - size.width / 2
        let preferredY = visibleFrame.maxY - size.height - 24
        let y = max(preferredY, visibleFrame.minY + 20)

        return NSRect(
            x: x.rounded(.down),
            y: y.rounded(.down),
            width: size.width,
            height: size.height
        )
    }

    func windowDidResignKey(_ notification: Notification) {
        hide(restoreFocus: false)
    }
}

private final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
