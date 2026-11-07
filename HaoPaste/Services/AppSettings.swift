//
//  AppSettings.swift
//  HaoPaste
//
//  UserDefaults-backed preferences shared by the app, panel and settings window.
//

import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    static let historyLimitOptions = [100, 200, 500, 1_000]
    static let defaultHistoryLimit = 200

    private enum Keys {
        static let maxUnpinnedItems = "settings.maxUnpinnedItems"
        static let hotKeyCode = "settings.hotKeyCode"
        static let hotKeyModifiers = "settings.hotKeyModifiers"
    }

    var maxUnpinnedItems: Int {
        didSet {
            let validated = Self.historyLimitOptions.contains(maxUnpinnedItems)
                ? maxUnpinnedItems
                : Self.defaultHistoryLimit

            if validated != maxUnpinnedItems {
                maxUnpinnedItems = validated
                return
            }

            guard oldValue != maxUnpinnedItems else { return }
            defaults.set(maxUnpinnedItems, forKey: Keys.maxUnpinnedItems)
            onHistoryLimitChange?(maxUnpinnedItems)
        }
    }

    var hotKey: HotKeyConfiguration {
        didSet {
            guard oldValue != hotKey else { return }

            defaults.set(Int(hotKey.keyCode), forKey: Keys.hotKeyCode)
            defaults.set(Int(hotKey.carbonModifiers), forKey: Keys.hotKeyModifiers)

            if !isRevertingHotKey {
                onHotKeyChange?(hotKey)
            }
        }
    }

    private(set) var hotKeyRegistrationError: String?

    private(set) var launchAtLoginEnabled: Bool
    private(set) var launchAtLoginRequiresApproval: Bool
    private(set) var launchAtLoginError: String?

    @ObservationIgnored var onHistoryLimitChange: ((Int) -> Void)?
    @ObservationIgnored var onHotKeyChange: ((HotKeyConfiguration) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isRevertingHotKey = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedLimit = defaults.integer(forKey: Keys.maxUnpinnedItems)
        self.maxUnpinnedItems = Self.historyLimitOptions.contains(storedLimit)
            ? storedLimit
            : Self.defaultHistoryLimit

        let storedKeyCode = defaults.integer(forKey: Keys.hotKeyCode)
        let storedModifiers = defaults.integer(forKey: Keys.hotKeyModifiers)
        let storedHotKey = HotKeyConfiguration(
            keyCode: UInt32(clamping: storedKeyCode),
            carbonModifiers: UInt32(clamping: storedModifiers)
        )
        self.hotKey = storedHotKey.isValid ? storedHotKey : .default

        let loginStatus = SMAppService.mainApp.status
        self.launchAtLoginEnabled = loginStatus == .enabled
        self.launchAtLoginRequiresApproval = loginStatus == .requiresApproval
        self.launchAtLoginError = nil
    }

    // MARK: - Hotkey

    func setHotKeyRegistrationError(_ message: String?) {
        hotKeyRegistrationError = message
    }

    /// Called when a new shortcut could not be registered. This updates the
    /// stored value without triggering another registration attempt.
    func revertHotKey(to configuration: HotKeyConfiguration) {
        guard hotKey != configuration else { return }
        isRevertingHotKey = true
        hotKey = configuration
        isRevertingHotKey = false
    }

    func resetHotKeyToDefault() {
        hotKey = .default
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        let service = SMAppService.mainApp

        do {
            switch (enabled, service.status) {
            case (true, .enabled), (false, .notRegistered):
                break
            case (true, _):
                try service.register()
            case (false, _):
                try service.unregister()
            }
        } catch {
            launchAtLoginError = "无法更新登录项：\(error.localizedDescription)"
        }

        refreshLaunchAtLoginStatus()

        if enabled, service.status == .requiresApproval {
            launchAtLoginError = "请在“系统设置 → 通用 → 登录项”中允许 HaoPaste 在登录时打开。"
        }
    }

    func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled
        launchAtLoginRequiresApproval = status == .requiresApproval
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
