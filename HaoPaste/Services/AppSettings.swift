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
    static let unlimitedShelfItemLimit = -1
    static let shelfItemLimitOptions = [
        6, 8, 10, 12, unlimitedShelfItemLimit
    ]
    static let defaultShelfItemLimit = 8
    static let defaultShelfEdge = ClipboardShelfEdge.top

    private enum Keys {
        static let maxUnpinnedItems = "settings.maxUnpinnedItems"
        static let hotKeyCode = "settings.hotKeyCode"
        static let hotKeyModifiers = "settings.hotKeyModifiers"
        static let capturesImages = "settings.capturesImages"
        static let excludedApplications = "settings.excludedApplications"
        static let translationHotKeyCode = "settings.translationHotKeyCode"
        static let translationHotKeyModifiers = "settings.translationHotKeyModifiers"
        static let autoTranslateLatestOnOpen = "settings.autoTranslateLatestOnOpen"
        static let shelfEnabled = "settings.shelfEnabled"
        static let shelfItemLimit = "settings.shelfItemLimit"
        static let shelfEdge = "settings.shelfEdge"
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

    var translationHotKey: HotKeyConfiguration {
        didSet {
            guard oldValue != translationHotKey else { return }

            defaults.set(
                Int(translationHotKey.keyCode),
                forKey: Keys.translationHotKeyCode
            )
            defaults.set(
                Int(translationHotKey.carbonModifiers),
                forKey: Keys.translationHotKeyModifiers
            )

            if !isRevertingTranslationHotKey {
                onTranslationHotKeyChange?(translationHotKey)
            }
        }
    }

    var autoTranslateLatestOnOpen: Bool {
        didSet {
            guard oldValue != autoTranslateLatestOnOpen else { return }
            defaults.set(
                autoTranslateLatestOnOpen,
                forKey: Keys.autoTranslateLatestOnOpen
            )
        }
    }

    var shelfEnabled: Bool {
        didSet {
            guard oldValue != shelfEnabled else { return }
            defaults.set(shelfEnabled, forKey: Keys.shelfEnabled)
            onShelfEnabledChange?(shelfEnabled)
        }
    }

    var shelfEdge: ClipboardShelfEdge {
        didSet {
            guard oldValue != shelfEdge else { return }
            defaults.set(shelfEdge.rawValue, forKey: Keys.shelfEdge)
            onShelfEdgeChange?(shelfEdge)
        }
    }

    var shelfItemLimit: Int {
        didSet {
            let validated = Self.shelfItemLimitOptions.contains(shelfItemLimit)
                ? shelfItemLimit
                : Self.defaultShelfItemLimit

            if validated != shelfItemLimit {
                shelfItemLimit = validated
                return
            }

            guard oldValue != shelfItemLimit else { return }
            defaults.set(shelfItemLimit, forKey: Keys.shelfItemLimit)
        }
    }

    var capturesImages: Bool {
        didSet {
            guard oldValue != capturesImages else { return }
            defaults.set(capturesImages, forKey: Keys.capturesImages)
        }
    }

    private(set) var excludedApplications: [ExcludedApplication]

    private(set) var hotKeyRegistrationError: String?
    private(set) var translationHotKeyRegistrationError: String?

    private(set) var launchAtLoginEnabled: Bool
    private(set) var launchAtLoginRequiresApproval: Bool
    private(set) var launchAtLoginError: String?

    @ObservationIgnored var onHistoryLimitChange: ((Int) -> Void)?
    @ObservationIgnored var onHotKeyChange: ((HotKeyConfiguration) -> Void)?
    @ObservationIgnored var onTranslationHotKeyChange: ((HotKeyConfiguration) -> Void)?
    @ObservationIgnored var onShelfEnabledChange: ((Bool) -> Void)?
    @ObservationIgnored var onShelfEdgeChange: ((ClipboardShelfEdge) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isRevertingHotKey = false
    @ObservationIgnored private var isRevertingTranslationHotKey = false

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

        let storedTranslationKeyCode = defaults.integer(
            forKey: Keys.translationHotKeyCode
        )
        let storedTranslationModifiers = defaults.integer(
            forKey: Keys.translationHotKeyModifiers
        )
        let storedTranslationHotKey = HotKeyConfiguration(
            keyCode: UInt32(clamping: storedTranslationKeyCode),
            carbonModifiers: UInt32(clamping: storedTranslationModifiers)
        )
        self.translationHotKey = storedTranslationHotKey.isValid
            ? storedTranslationHotKey
            : .translationDefault

        if defaults.object(forKey: Keys.autoTranslateLatestOnOpen) == nil {
            self.autoTranslateLatestOnOpen = true
        } else {
            self.autoTranslateLatestOnOpen = defaults.bool(
                forKey: Keys.autoTranslateLatestOnOpen
            )
        }

        if defaults.object(forKey: Keys.shelfEnabled) == nil {
            self.shelfEnabled = true
        } else {
            self.shelfEnabled = defaults.bool(forKey: Keys.shelfEnabled)
        }

        let storedShelfLimit = defaults.integer(forKey: Keys.shelfItemLimit)
        self.shelfItemLimit = Self.shelfItemLimitOptions.contains(storedShelfLimit)
            ? storedShelfLimit
            : Self.defaultShelfItemLimit

        let storedShelfEdge = defaults.string(forKey: Keys.shelfEdge)
            .flatMap(ClipboardShelfEdge.init(rawValue:))
        self.shelfEdge = storedShelfEdge ?? Self.defaultShelfEdge

        if defaults.object(forKey: Keys.capturesImages) == nil {
            self.capturesImages = true
        } else {
            self.capturesImages = defaults.bool(forKey: Keys.capturesImages)
        }

        if
            let data = defaults.data(forKey: Keys.excludedApplications),
            let decoded = try? JSONDecoder().decode([ExcludedApplication].self, from: data)
        {
            self.excludedApplications = decoded.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } else {
            self.excludedApplications = []
        }

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

    func setTranslationHotKeyRegistrationError(_ message: String?) {
        translationHotKeyRegistrationError = message
    }

    func revertTranslationHotKey(to configuration: HotKeyConfiguration) {
        guard translationHotKey != configuration else { return }
        isRevertingTranslationHotKey = true
        translationHotKey = configuration
        isRevertingTranslationHotKey = false
    }

    func resetTranslationHotKeyToDefault() {
        translationHotKey = .translationDefault
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

    // MARK: - Privacy

    func isSourceExcluded(_ source: SourceApplication) -> Bool {
        if let sourceIdentifier = source.bundleIdentifier, !sourceIdentifier.isEmpty {
            if excludedApplications.contains(where: {
                $0.bundleIdentifier?.caseInsensitiveCompare(sourceIdentifier) == .orderedSame
            }) {
                return true
            }
        }

        // Fall back to the display name when the source app has no bundle ID.
        if source.bundleIdentifier == nil || source.bundleIdentifier?.isEmpty == true {
            return excludedApplications.contains {
                $0.name.caseInsensitiveCompare(source.name) == .orderedSame
            }
        }

        return false
    }

    func addExcludedApplications(_ applications: [ExcludedApplication]) {
        guard !applications.isEmpty else { return }

        var merged = excludedApplications

        for application in applications {
            let normalized = ExcludedApplication(
                bundleIdentifier: application.bundleIdentifier,
                name: application.name
            )
            guard !normalized.name.isEmpty else { continue }
            guard !merged.contains(where: { $0.id == normalized.id }) else { continue }
            merged.append(normalized)
        }

        excludedApplications = merged.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        persistExcludedApplications()
    }

    func removeExcludedApplication(_ application: ExcludedApplication) {
        guard excludedApplications.contains(where: { $0.id == application.id }) else {
            return
        }

        excludedApplications = excludedApplications.filter { $0.id != application.id }
        persistExcludedApplications()
    }

    private func persistExcludedApplications() {
        do {
            let data = try JSONEncoder().encode(excludedApplications)
            defaults.set(data, forKey: Keys.excludedApplications)
        } catch {
            NSLog("HaoPaste: could not persist excluded applications — \(error.localizedDescription)")
        }
    }
}
