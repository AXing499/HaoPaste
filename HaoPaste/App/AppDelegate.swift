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
    private var settings: AppSettings!
    private var settingsWindowController: SettingsWindowController?

    private var hotKey: GlobalHotKey?
    private var activeHotKeyConfiguration: HotKeyConfiguration?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()

        settings = AppSettings()
        settings.refreshLaunchAtLoginStatus()

        manager = ClipboardManager()
        manager.start()
        manager.updateMaxUnpinnedItems(settings.maxUnpinnedItems)
        settings.onHistoryLimitChange = { [weak self] limit in
            self?.manager.updateMaxUnpinnedItems(limit)
        }

        #if DEBUG
        if renderPreviewIfRequested() {
            return
        }
        #endif

        panelController = PanelController(manager: manager)
        statusBarController = StatusBarController(
            manager: manager,
            panelController: panelController,
            settings: settings,
            onOpenSettings: { [weak self] in
                self?.showSettings()
            }
        )

        settings.onHotKeyChange = { [weak self] configuration in
            self?.applyHotKey(configuration)
        }
        applyHotKey(settings.hotKey)

        #if DEBUG
        if CommandLine.arguments.contains("--demo") {
            manager.seedDemoDataIfNeeded()
        }

        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.showSettings()
            }
            return
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

    // MARK: - Settings

    private func showSettings() {
        panelController?.hide(restoreFocus: false)

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                manager: manager,
                settings: settings
            )
        }

        settingsWindowController?.show()
    }

    @objc
    private func openSettingsFromMenu() {
        showSettings()
    }

    // MARK: - Hotkey

    private func applyHotKey(_ configuration: HotKeyConfiguration) {
        let fallback = activeHotKeyConfiguration ?? .default

        do {
            try installHotKey(configuration)
            activeHotKeyConfiguration = configuration
            settings.setHotKeyRegistrationError(nil)
        } catch {
            var message = "无法注册 \(configuration.displayString)：\(error.localizedDescription)"

            if configuration != fallback {
                do {
                    try installHotKey(fallback)
                    activeHotKeyConfiguration = fallback
                    settings.revertHotKey(to: fallback)
                    message += " 已恢复为 \(fallback.displayString)。"
                } catch {
                    activeHotKeyConfiguration = nil
                    message += " 原快捷键也无法注册。"
                }
            } else {
                activeHotKeyConfiguration = nil
            }

            settings.setHotKeyRegistrationError(message)
            NSLog("HaoPaste: \(message)")
        }

        statusBarController?.refreshShortcutDisplay()
    }

    private func installHotKey(_ configuration: HotKeyConfiguration) throws {
        hotKey = nil
        hotKey = try GlobalHotKey(
            keyCode: configuration.keyCode,
            modifiers: configuration.carbonModifiers
        ) { [weak self] in
            // The Carbon handler can run before AppKit finishes processing the
            // key event; hop to the next main-loop turn before showing a window.
            DispatchQueue.main.async {
                self?.panelController.toggle()
            }
        }
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
    /// `--render <path>` and `--render-settings <path>` produce off-screen
    /// screenshots for design review.
    private func renderPreviewIfRequested() -> Bool {
        let arguments = CommandLine.arguments

        func value(after flag: String) -> String? {
            guard
                let index = arguments.firstIndex(of: flag),
                arguments.indices.contains(index + 1)
            else {
                return nil
            }
            return arguments[index + 1]
        }

        if let path = value(after: "--render-settings") {
            manager.seedDemoDataIfNeeded()
            DebugRenderer.renderSettings(
                manager: manager,
                settings: settings,
                to: URL(fileURLWithPath: path)
            ) {
                NSApp.terminate(nil)
            }
            return true
        }

        guard let path = value(after: "--render") else {
            return false
        }

        manager.seedDemoDataIfNeeded()
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

        let settingsItem = appMenu.addItem(
            withTitle: "设置…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self

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

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)

        let windowMenu = NSMenu(title: "窗口")
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(
            withTitle: "关闭",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        windowMenu.addItem(
            withTitle: "最小化",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )

        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }
}
