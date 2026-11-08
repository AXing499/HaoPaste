//
//  SettingsWindowController.swift
//  HaoPaste
//
//  Hosts the SwiftUI settings view in a standard macOS window.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(
        manager: ClipboardManager,
        settings: AppSettings,
        snippetManager: SnippetManager,
        translationService: TranslationService,
        ocrService: OCRService,
        initialTab: SettingsTab = .general
    ) {
        let rootView = SettingsView(
            settings: settings,
            manager: manager,
            translationService: translationService,
            initialTab: initialTab
        )
        .environment(snippetManager)
        .environment(ocrService)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HaoPaste 设置"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.center()
        window.setFrameAutosaveName("HaoPasteSettingsWindow")

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate()
        _ = NSRunningApplication.current.activate(options: [.activateAllWindows])
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
