//
//  StatusBarController.swift
//  HaoPaste
//
//  Menu bar presence: left click toggles the panel, right click opens options.
//

import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let manager: ClipboardManager
    private let settings: AppSettings
    private weak var panelController: PanelController?
    private weak var quickTranslationController: QuickTranslationPanelController?
    private let onOpenSettings: () -> Void

    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private let showItem = NSMenuItem()
    private let translateItem = NSMenuItem()
    private let historyInfoItem = NSMenuItem()
    private let pauseItem = NSMenuItem()
    private let clearItem = NSMenuItem()

    init(
        manager: ClipboardManager,
        panelController: PanelController,
        quickTranslationController: QuickTranslationPanelController,
        settings: AppSettings,
        onOpenSettings: @escaping () -> Void
    ) {
        self.manager = manager
        self.settings = settings
        self.panelController = panelController
        self.quickTranslationController = quickTranslationController
        self.onOpenSettings = onOpenSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        super.init()

        configureStatusItem()
        buildMenu()
        updatePresentation()
    }

    // MARK: - Status item

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = symbolImage(named: "doc.on.clipboard", pointSize: 14, weight: .medium)
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "HaoPaste · \(settings.hotKey.displayString)"
    }

    @objc
    private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondaryClick = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if isSecondaryClick {
            showContextMenu()
        } else {
            panelController?.toggle()
        }
    }

    private func showContextMenu() {
        updatePresentation()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Menu

    private func buildMenu() {
        menu.autoenablesItems = false
        menu.delegate = self

        showItem.title = "打开 HaoPaste（\(settings.hotKey.displayString)）"
        showItem.action = #selector(showPanel)
        showItem.keyEquivalent = ""
        showItem.target = self
        showItem.image = symbolImage(named: "macwindow", pointSize: 13, weight: .regular)
        menu.addItem(showItem)

        translateItem.title = "翻译剪贴板（\(settings.translationHotKey.displayString)）"
        translateItem.action = #selector(translateClipboard)
        translateItem.keyEquivalent = ""
        translateItem.target = self
        translateItem.image = symbolImage(
            named: "character.bubble",
            pointSize: 13,
            weight: .regular
        )
        menu.addItem(translateItem)

        historyInfoItem.title = "暂无记录"
        historyInfoItem.isEnabled = false
        historyInfoItem.image = symbolImage(named: "clock.arrow.circlepath", pointSize: 13, weight: .regular)
        menu.addItem(historyInfoItem)

        menu.addItem(.separator())

        pauseItem.target = self
        pauseItem.action = #selector(toggleMonitoring)
        menu.addItem(pauseItem)

        clearItem.title = "清空未置顶记录"
        clearItem.target = self
        clearItem.action = #selector(clearUnpinned)
        clearItem.image = symbolImage(named: "trash", pointSize: 13, weight: .regular)
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        settingsItem.image = symbolImage(named: "gearshape", pointSize: 13, weight: .regular)
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "关于 HaoPaste",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        aboutItem.image = symbolImage(named: "info.circle", pointSize: 13, weight: .regular)
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(
            title: "退出 HaoPaste",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = symbolImage(named: "power", pointSize: 13, weight: .regular)
        menu.addItem(quitItem)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updatePresentation()
    }

    func refreshShortcutDisplay() {
        updatePresentation()
    }

    private func updatePresentation() {
        showItem.title = "打开 HaoPaste（\(settings.hotKey.displayString)）"
        translateItem.title = "翻译剪贴板（\(settings.translationHotKey.displayString)）"

        historyInfoItem.title = manager.items.isEmpty
            ? "暂无记录"
            : "\(manager.items.count) 条记录 · \(manager.pinnedCount) 条置顶"

        pauseItem.title = manager.isMonitoringPaused ? "继续监听" : "暂停监听"
        pauseItem.image = symbolImage(
            named: manager.isMonitoringPaused ? "play.circle" : "pause.circle",
            pointSize: 13,
            weight: .regular
        )

        clearItem.isEnabled = manager.hasUnpinnedItems

        statusItem.button?.appearsDisabled = manager.isMonitoringPaused
        statusItem.button?.toolTip = manager.isMonitoringPaused
            ? "HaoPaste · 监听已暂停"
            : "HaoPaste · \(settings.hotKey.displayString)"
    }

    // MARK: - Actions

    @objc
    private func showPanel() {
        panelController?.show()
    }

    @objc
    private func translateClipboard() {
        quickTranslationController?.translateClipboard()
    }

    @objc
    private func openSettings() {
        onOpenSettings()
    }

    @objc
    private func toggleMonitoring() {
        manager.toggleMonitoringPaused()
        updatePresentation()
    }

    @objc
    private func clearUnpinned() {
        guard manager.hasUnpinnedItems else { return }

        let previousApplication = NSWorkspace.shared.frontmostApplication

        let alert = NSAlert()
        alert.messageText = "清空未置顶记录？"
        alert.informativeText = manager.pinnedCount > 0
            ? "已置顶的 \(manager.pinnedCount) 条记录会保留。此操作无法撤销。"
            : "所有历史记录都会被删除。此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")

        NSApp.activate()
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            manager.clearUnpinnedItems()
        }

        updatePresentation()

        if let previousApplication,
           previousApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication.activate(options: [])
        }
    }

    @objc
    private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func symbolImage(
        named name: String,
        pointSize: CGFloat,
        weight: NSFont.Weight
    ) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        return image
    }
}
