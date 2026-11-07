//
//  HaoPasteApplication.swift
//  HaoPaste
//
//  AppKit entry point. A status-bar-only app with a custom floating panel.
//

import AppKit

@main
enum HaoPasteApplication {
    @MainActor
    private static var retainedDelegate: AppDelegate?

    @MainActor
    static func main() {
        let app = NSApplication.shared

        let delegate = AppDelegate()
        retainedDelegate = delegate
        app.delegate = delegate

        app.setActivationPolicy(.accessory)
        app.run()
    }
}
