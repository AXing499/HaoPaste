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
    private var snippetManager: SnippetManager!
    private var panelController: PanelController!
    private var statusBarController: StatusBarController!
    private var settings: AppSettings!
    private var translationService: TranslationService!
    private var quickTranslationService: TranslationService!
    private var quickTranslationController: QuickTranslationPanelController!
    private var shelfController: ClipboardShelfController!
    private var shelfPreviewController: ShelfPreviewPanelController!
    private var shelfOCRService: OCRService!
    private var shelfOCRController: ShelfOCRPanelController!
    private var ocrService: OCRService!
    private var settingsWindowController: SettingsWindowController?

    private var hotKey: GlobalHotKey?
    private var activeHotKeyConfiguration: HotKeyConfiguration?
    private var translationHotKey: GlobalHotKey?
    private var activeTranslationHotKeyConfiguration: HotKeyConfiguration?

    private var isRunningUnitTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run in the host application. Do not create the status item,
        // start pasteboard polling or register a global hotkey in that mode.
        guard !isRunningUnitTests else { return }

        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()

        settings = AppSettings()
        settings.refreshLaunchAtLoginStatus()
        snippetManager = SnippetManager()
        translationService = TranslationService()
        ocrService = OCRService()

        manager = ClipboardManager()
        manager.isSourceExcluded = { [weak settings] source in
            settings?.isSourceExcluded(source) ?? false
        }
        manager.isImageCaptureEnabled = { [weak settings] in
            settings?.capturesImages ?? true
        }
        manager.start()
        manager.updateMaxUnpinnedItems(settings.maxUnpinnedItems)
        settings.onHistoryLimitChange = { [weak self] limit in
            self?.manager.updateMaxUnpinnedItems(limit)
        }

        #if DEBUG
        if runArchiveCommandIfRequested() {
            return
        }

        if renderPreviewIfRequested() {
            return
        }
        #endif

        panelController = PanelController(
            manager: manager,
            snippetManager: snippetManager,
            translationService: translationService,
            ocrService: ocrService,
            settings: settings
        )

        quickTranslationService = TranslationService(
            settings: translationService.settings,
            credentials: translationService.credentials
        )
        quickTranslationController = QuickTranslationPanelController(
            manager: manager,
            service: quickTranslationService,
            snippetManager: snippetManager
        )
        quickTranslationController.onWillPresent = { [weak self] source in
            self?.panelController?.hide(restoreFocus: false)
            if source == .hotKey {
                self?.shelfController?.hideIfVisible()
            }
        }

        shelfPreviewController = ShelfPreviewPanelController(manager: manager)
        shelfOCRService = OCRService()
        shelfOCRController = ShelfOCRPanelController(
            manager: manager,
            service: shelfOCRService
        )
        wireShelfDetailControllers()

        shelfController = ClipboardShelfController(
            manager: manager,
            settings: settings
        )

        statusBarController = StatusBarController(
            manager: manager,
            panelController: panelController,
            quickTranslationController: quickTranslationController,
            shelfController: shelfController,
            settings: settings,
            onOpenSettings: { [weak self] in
                self?.showSettings()
            }
        )
        shelfController.onVisibilityChanged = { [weak self] in
            self?.statusBarController?.refreshShortcutDisplay()
        }
        shelfController.onPreviewItem = { [weak self] item, anchor in
            guard let self, let anchor else { return }
            self.shelfPreviewController.present(
                item: item,
                anchor: anchor,
                edge: self.shelfController.currentEdge
            )
        }
        shelfController.onTranslateItem = { [weak self] item, anchor in
            guard let self, let anchor else { return }
            let edge = self.shelfController.currentEdge
            if item.type == .image {
                guard let imageURL = self.manager.imageURL(for: item) else {
                    return
                }
                self.shelfOCRController.present(
                    item: item,
                    imageURL: imageURL,
                    translateAfterRecognition: false,
                    anchor: anchor,
                    edge: edge
                )
            } else {
                self.quickTranslationController.translate(
                    text: item.content,
                    title: item.displayTitle,
                    anchor: anchor,
                    edge: edge
                )
            }
        }
        shelfController.onWillHide = { [weak self] in
            guard let self else { return }
            self.shelfPreviewController.close()
            self.shelfOCRController.close()
            if self.quickTranslationController.isVisibleFromShelf {
                self.quickTranslationController.hide()
            }
        }
        shelfController.isRetractBlocked = { [weak self] in
            guard let self else { return false }
            return self.shelfPreviewController.isVisible
                || self.shelfOCRController.isVisible
                || self.quickTranslationController.isVisibleFromShelf
        }
        panelController.onWillPresent = { [weak self] in
            self?.shelfController?.hideIfVisible()
        }
        shelfController.isRevealBlocked = { [weak self] in
            guard let self else { return true }
            return self.panelController.isVisible
                || self.quickTranslationController.isVisible
        }
        settings.onShelfEnabledChange = { [weak self] enabled in
            self?.shelfController.setEnabled(enabled)
        }
        settings.onShelfEdgeChange = { [weak self] _ in
            self?.shelfController.edgeDidChange()
        }

        settings.onHotKeyChange = { [weak self] configuration in
            self?.applyHotKey(configuration)
        }
        applyHotKey(settings.hotKey)

        settings.onTranslationHotKeyChange = { [weak self] configuration in
            self?.applyTranslationHotKey(configuration)
        }
        applyTranslationHotKey(settings.translationHotKey)

        NotificationCenter.default.addObserver(
            forName: .haopasteOpenTranslationSettings,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                (NSApp.delegate as? AppDelegate)?
                    .showSettings(initialTab: .intelligence)
            }
        }

        #if DEBUG
        if CommandLine.arguments.contains("--show-shelf") {
            manager.seedDemoDataIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.shelfController?.toggle()
            }
            return
        }

        if CommandLine.arguments.contains("--show-quick") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                "Design is not just what it looks like. Design is how it works.",
                forType: .string
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.quickTranslationController?.translateClipboard()
            }
            return
        }

        if CommandLine.arguments.contains("--demo") {
            manager.seedDemoDataIfNeeded()
            snippetManager.seedDemoSnippetsIfNeeded()
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

    private func wireShelfDetailControllers() {
        let translate: (
            String,
            String,
            NSRect,
            ClipboardShelfEdge
        ) -> Void = { [weak self] text, title, anchor, edge in
            self?.quickTranslationController.translate(
                text: text,
                title: title,
                anchor: anchor,
                edge: edge
            )
        }

        shelfPreviewController.onTranslateText = translate
        shelfOCRController.onTranslateText = translate

        shelfPreviewController.onExtractText = {
            [weak self] item, imageURL, anchor, edge in
            self?.shelfOCRController.present(
                item: item,
                imageURL: imageURL,
                translateAfterRecognition: false,
                anchor: anchor,
                edge: edge
            )
        }
        shelfPreviewController.onExtractAndTranslate = {
            [weak self] item, imageURL, anchor, edge in
            self?.shelfOCRController.present(
                item: item,
                imageURL: imageURL,
                translateAfterRecognition: true,
                anchor: anchor,
                edge: edge
            )
        }
        shelfOCRController.onSaveSnippet = { [weak self] text in
            guard let self, !text.isEmpty else { return }
            let source = self.shelfOCRService.sourceTitle
            let rawTitle = source.isEmpty ? "图片文字" : source
            let title = rawTitle.count > 20
                ? String(rawTitle.prefix(20)) + "…"
                : rawTitle
            _ = self.snippetManager.create(
                title: "识图 · \(title)",
                content: text
            )
        }
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

    private func showSettings(initialTab: SettingsTab = .general) {
        panelController?.hide(restoreFocus: false)

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                manager: manager,
                settings: settings,
                snippetManager: snippetManager,
                translationService: translationService,
                ocrService: ocrService,
                initialTab: initialTab
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

    private func applyTranslationHotKey(_ configuration: HotKeyConfiguration) {
        let fallback = activeTranslationHotKeyConfiguration ?? .translationDefault

        do {
            try installTranslationHotKey(configuration)
            activeTranslationHotKeyConfiguration = configuration
            settings.setTranslationHotKeyRegistrationError(nil)
        } catch {
            var message = "无法注册翻译快捷键 \(configuration.displayString)：\(error.localizedDescription)"

            if configuration != fallback {
                do {
                    try installTranslationHotKey(fallback)
                    activeTranslationHotKeyConfiguration = fallback
                    settings.revertTranslationHotKey(to: fallback)
                    message += " 已恢复为 \(fallback.displayString)。"
                } catch {
                    activeTranslationHotKeyConfiguration = nil
                    message += " 原翻译快捷键也无法注册。"
                }
            } else {
                activeTranslationHotKeyConfiguration = nil
            }

            settings.setTranslationHotKeyRegistrationError(message)
            NSLog("HaoPaste: \(message)")
        }

        statusBarController?.refreshShortcutDisplay()
    }

    private func installTranslationHotKey(_ configuration: HotKeyConfiguration) throws {
        translationHotKey = nil
        translationHotKey = try GlobalHotKey(
            keyCode: configuration.keyCode,
            modifiers: configuration.carbonModifiers,
            id: 2
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.quickTranslationController?.translateClipboard()
            }
        }
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
    private func runArchiveCommandIfRequested() -> Bool {
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

        if let path = value(after: "--export-history") {
            do {
                let summary = try manager.exportHistory(
                    to: URL(fileURLWithPath: path),
                    snippets: snippetManager.snippets
                )
                NSLog(
                    "HaoPaste: exported \(summary.itemCount) items, \(summary.imageCount) images, \(summary.snippetCount) snippets"
                )
            } catch {
                NSLog("HaoPaste: export failed — \(error.localizedDescription)")
            }
            manager.shutdown()
            NSApp.terminate(nil)
            return true
        }

        if let path = value(after: "--import-history") {
            do {
                let summary = try manager.importHistory(
                    from: URL(fileURLWithPath: path)
                )
                let snippetMerge = snippetManager.mergeImported(summary.snippets)
                NSLog(
                    "HaoPaste: imported \(summary.importedCount), merged pins \(summary.mergedPinnedCount), skipped \(summary.skippedCount), trimmed \(summary.trimmedCount), snippets added \(snippetMerge.added)"
                )
            } catch {
                NSLog("HaoPaste: import failed — \(error.localizedDescription)")
            }
            manager.shutdown()
            NSApp.terminate(nil)
            return true
        }

        return false
    }

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

        if let path = value(after: "--render-shelf") {
            manager.seedDemoDataIfNeeded()
            DebugRenderer.renderShelf(
                manager: manager,
                settings: settings,
                to: URL(fileURLWithPath: path)
            ) {
                NSApp.terminate(nil)
            }
            return true
        }

        if let path = value(after: "--render-quick") {
            manager.seedDemoDataIfNeeded()
            DebugRenderer.renderQuickTranslation(
                service: translationService,
                to: URL(fileURLWithPath: path)
            ) {
                NSApp.terminate(nil)
            }
            return true
        }

        if let path = value(after: "--render-settings") {
            manager.seedDemoDataIfNeeded()
            snippetManager.seedDemoSnippetsIfNeeded()
            DebugRenderer.renderSettings(
                manager: manager,
                settings: settings,
                snippetManager: snippetManager,
                translationService: translationService,
                ocrService: ocrService,
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
        snippetManager.seedDemoSnippetsIfNeeded()
        DebugRenderer.renderPanel(
            manager: manager,
            snippetManager: snippetManager,
            translationService: translationService,
            ocrService: ocrService,
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
