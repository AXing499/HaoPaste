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
            initialTab: initialTab,
            showsWindowChrome: true
        )
        .environment(snippetManager)
        .environment(ocrService)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        window.title = L("HaoPaste 设置")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentViewController = hostingController
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.center()
        window.setFrameAutosaveName("HaoPasteSettingsWindow")
        // The autosaved frame may come from the pre-glass window, whose
        // titlebar added 32 pt. Keep the content at the design size while
        // preserving the remembered window origin.
        window.setContentSize(NSSize(width: 720, height: 480))

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
