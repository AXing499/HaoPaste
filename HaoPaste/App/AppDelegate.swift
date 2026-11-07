//
//  AppDelegate.swift
//  HaoPaste
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum LaunchDefaults {
        static let hasCompletedFirstLaunch = "hasCompletedFirstLaunch"
    }

    private var manager: ClipboardManager!
    private var panelController: PanelController!
    private var statusBarController: StatusBarController!
    private var hotKey: GlobalHotKey!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()

        manager = ClipboardManager()
        manager.start()

        #if DEBUG
        if renderPreviewIfRequested() {
            return
        }
        #endif

        panelController = PanelController(manager: manager)
        statusBarController = StatusBarController(
            manager: manager,
            panelController: panelController
        )

        hotKey = GlobalHotKey.makeDefault { [weak self] in
            // The Carbon handler can run before AppKit finishes processing the
            // key event; hop to the next main-loop turn before showing a window.
            DispatchQueue.main.async {
                self?.panelController.toggle()
            }
        }

        #if DEBUG
        if CommandLine.arguments.contains("--demo") {
            manager.seedDemoDataIfNeeded()
        }
        #endif

        showPanelOnLaunchIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager?.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Double-clicking the app again while it is already running should reveal
    /// the panel instead of appearing to do nothing (there is no Dock icon).
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        panelController?.show()
        return false
    }

    private func showPanelOnLaunchIfNeeded() {
        let arguments = CommandLine.arguments
        let isDebugPresentation = arguments.contains("--show") || arguments.contains("--demo")

        if isDebugPresentation {
            schedulePanelPresentation()
            return
        }

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: LaunchDefaults.hasCompletedFirstLaunch) else {
            return
        }

        // A menu-bar-only app can look like it did not start. Show the panel
        // once on first launch, then rely on ⌥⌘V and the status item afterwards.
        defaults.set(true, forKey: LaunchDefaults.hasCompletedFirstLaunch)
        schedulePanelPresentation()
    }

    private func schedulePanelPresentation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.panelController.show()
        }
    }

    #if DEBUG
    /// `--render <path>` produces an off-screen screenshot for design review.
    private func renderPreviewIfRequested() -> Bool {
        guard
            let flagIndex = CommandLine.arguments.firstIndex(of: "--render"),
            CommandLine.arguments.indices.contains(flagIndex + 1)
        else {
            return false
        }

        manager.seedDemoDataIfNeeded()
        let path = CommandLine.arguments[flagIndex + 1]
        DebugRenderer.renderPanel(
            manager: manager,
            to: URL(fileURLWithPath: path)
        ) {
            NSApp.terminate(nil)
        }
        return true
    }
    #endif

    // MARK: - Main menu

    /// An accessory app normally hides the menu bar. The main menu still exists so
    /// standard text editing shortcuts (⌘C, ⌘V, ⌘A…) work inside the search field.
    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "HaoPaste")
        appMenuItem.submenu = appMenu

        let aboutItem = appMenu.addItem(
            withTitle: "关于 HaoPaste",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = NSApp

        appMenu.addItem(.separator())

        let hideItem = appMenu.addItem(
            withTitle: "隐藏 HaoPaste",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApp

        appMenu.addItem(.separator())

        let quitItem = appMenu.addItem(
            withTitle: "退出 HaoPaste",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu

        editMenu.addItem(
            withTitle: "撤销",
            action: Selector(("undo:")),
            keyEquivalent: "z"
        )
        editMenu.addItem(
            withTitle: "重做",
            action: Selector(("redo:")),
            keyEquivalent: "Z"
        )
        editMenu.addItem(.separator())
        editMenu.addItem(
            withTitle: "剪切",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        editMenu.addItem(
            withTitle: "复制",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        editMenu.addItem(
            withTitle: "粘贴",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        editMenu.addItem(
            withTitle: "全选",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )

        NSApp.mainMenu = mainMenu
    }
}
