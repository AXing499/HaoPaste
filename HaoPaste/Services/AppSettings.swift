//
//  AppSettings.swift
//  HaoPaste
//
//  UserDefaults-backed preferences shared by the app, panel and settings window.
//

import Foundation
import Observation
import ServiceManagement

enum CopyBehavior: String, CaseIterable, Identifiable, Codable, Sendable {
    case stayOpen
    case hideImmediately
    case hideAfterDelay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stayOpen: return L("保持展开")
        case .hideImmediately: return L("立即收起")
        case .hideAfterDelay: return L("延迟 0.6 秒收起")
        }
    }
}

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
    static let trashRetentionOptions = [1, 7, 30, 90]
    static let defaultTrashRetentionDays = 7
    static let shelfCardFallDurationOptions: [Double] = [0.3, 0.5, 0.75, 1.0, 1.2]
    static let defaultShelfCardFallDuration: Double = 0.75
    static let defaultUpdateFeedURL =
        "https://api.github.com/repos/AXing499/HaoPaste/releases/latest"
    nonisolated static let liquidGlassDefaultsKey = "settings.liquidGlassEnabled"

    private enum Keys {
        static let maxUnpinnedItems = "settings.maxUnpinnedItems"
        static let hotKeyCode = "settings.hotKeyCode"
        static let hotKeyModifiers = "settings.hotKeyModifiers"
        static let capturesImages = "settings.capturesImages"
        static let excludedApplications = "settings.excludedApplications"
        static let translationHotKeyCode = "settings.translationHotKeyCode"
        static let translationHotKeyModifiers = "settings.translationHotKeyModifiers"
        static let pasteStackHotKeyCode = "settings.pasteStackHotKeyCode"
        static let pasteStackHotKeyModifiers = "settings.pasteStackHotKeyModifiers"
        static let screenshotHotKeyCode = "settings.screenshotHotKeyCode"
        static let screenshotHotKeyModifiers = "settings.screenshotHotKeyModifiers"
        static let autoTranslateLatestOnOpen = "settings.autoTranslateLatestOnOpen"
        static let autoTranslateDefaultOffMigrated = "settings.autoTranslateDefaultOffMigrated"
        static let trashRetentionDays = "settings.trashRetentionDays"
        static let shelfCardFallDuration = "settings.shelfCardFallDuration"
        static let updateFeedURL = "settings.updateFeedURL"
        static let shelfCopyBehavior = "settings.shelfCopyBehavior"
        static let panelCopyBehavior = "settings.panelCopyBehavior"
        static let selectionTranslationEnabled = "settings.selectionTranslationEnabled"
        static let copyPlainTextOnly = "settings.copyPlainTextOnly"
        static let copyTranslationWhenReplacing = "settings.copyTranslationWhenReplacing"
        static let liquidGlassEnabled = AppSettings.liquidGlassDefaultsKey
        static let shelfEnabled = "settings.shelfEnabled"
        static let shelfItemLimit = "settings.shelfItemLimit"
        static let shelfEdge = "settings.shelfEdge"
        static let appLanguage = AppLanguage.preferenceKey
    }

    var appLanguage: AppLanguagePreference {
        didSet {
            guard oldValue != appLanguage else { return }
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
        }
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

    var pasteStackHotKey: HotKeyConfiguration {
        didSet {
            guard oldValue != pasteStackHotKey else { return }

            defaults.set(
                Int(pasteStackHotKey.keyCode),
                forKey: Keys.pasteStackHotKeyCode
            )
            defaults.set(
                Int(pasteStackHotKey.carbonModifiers),
                forKey: Keys.pasteStackHotKeyModifiers
            )

            if !isRevertingPasteStackHotKey {
                onPasteStackHotKeyChange?(pasteStackHotKey)
            }
        }
    }

    var screenshotHotKey: HotKeyConfiguration {
        didSet {
            guard oldValue != screenshotHotKey else { return }

            defaults.set(
                Int(screenshotHotKey.keyCode),
                forKey: Keys.screenshotHotKeyCode
            )
            defaults.set(
                Int(screenshotHotKey.carbonModifiers),
                forKey: Keys.screenshotHotKeyModifiers
            )

            if !isRevertingScreenshotHotKey {
                onScreenshotHotKeyChange?(screenshotHotKey)
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

    var selectionTranslationEnabled: Bool {
        didSet {
            guard oldValue != selectionTranslationEnabled else { return }
            defaults.set(
                selectionTranslationEnabled,
                forKey: Keys.selectionTranslationEnabled
            )
            onSelectionTranslationEnabledChange?(selectionTranslationEnabled)
        }
    }

    var panelCopyBehavior: CopyBehavior {
        didSet {
            guard oldValue != panelCopyBehavior else { return }
            defaults.set(
                panelCopyBehavior.rawValue,
                forKey: Keys.panelCopyBehavior
            )
        }
    }

    var shelfCopyBehavior: CopyBehavior {
        didSet {
            guard oldValue != shelfCopyBehavior else { return }
            defaults.set(
                shelfCopyBehavior.rawValue,
                forKey: Keys.shelfCopyBehavior
            )
        }
    }

    var copyPlainTextOnly: Bool {
        didSet {
            guard oldValue != copyPlainTextOnly else { return }
            defaults.set(
                copyPlainTextOnly,
                forKey: Keys.copyPlainTextOnly
            )
        }
    }

    var copyTranslationWhenReplacing: Bool {
        didSet {
            guard oldValue != copyTranslationWhenReplacing else { return }
            defaults.set(
                copyTranslationWhenReplacing,
                forKey: Keys.copyTranslationWhenReplacing
            )
        }
    }

    var liquidGlassEnabled: Bool {
        didSet {
            guard oldValue != liquidGlassEnabled else { return }
            defaults.set(liquidGlassEnabled, forKey: Keys.liquidGlassEnabled)
        }
    }

    var updateFeedURL: String {
        didSet {
            guard oldValue != updateFeedURL else { return }
            defaults.set(updateFeedURL, forKey: Keys.updateFeedURL)
        }
    }

    var shelfCardFallDuration: Double {
        didSet {
            let validated = Self.shelfCardFallDurationOptions.contains(shelfCardFallDuration)
                ? shelfCardFallDuration
                : Self.defaultShelfCardFallDuration

            if validated != shelfCardFallDuration {
                shelfCardFallDuration = validated
                return
            }

            guard oldValue != shelfCardFallDuration else { return }
            defaults.set(
                shelfCardFallDuration,
                forKey: Keys.shelfCardFallDuration
            )
        }
    }

    var trashRetentionDays: Int {
        didSet {
            let validated = Self.trashRetentionOptions.contains(trashRetentionDays)
                ? trashRetentionDays
                : Self.defaultTrashRetentionDays

            if validated != trashRetentionDays {
                trashRetentionDays = validated
                return
            }

            guard oldValue != trashRetentionDays else { return }
            defaults.set(trashRetentionDays, forKey: Keys.trashRetentionDays)
            onTrashRetentionChange?(trashRetentionDays)
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
    private(set) var pasteStackHotKeyRegistrationError: String?
    private(set) var screenshotHotKeyRegistrationError: String?

    private(set) var launchAtLoginEnabled: Bool
    private(set) var launchAtLoginRequiresApproval: Bool
    private(set) var launchAtLoginError: String?

    @ObservationIgnored var onHistoryLimitChange: ((Int) -> Void)?
    @ObservationIgnored var onHotKeyChange: ((HotKeyConfiguration) -> Void)?
    @ObservationIgnored var onTranslationHotKeyChange: ((HotKeyConfiguration) -> Void)?
    @ObservationIgnored var onPasteStackHotKeyChange: ((HotKeyConfiguration) -> Void)?
    @ObservationIgnored var onScreenshotHotKeyChange: ((HotKeyConfiguration) -> Void)?
    @ObservationIgnored var onShelfEnabledChange: ((Bool) -> Void)?
    @ObservationIgnored var onShelfEdgeChange: ((ClipboardShelfEdge) -> Void)?
    @ObservationIgnored var onTrashRetentionChange: ((Int) -> Void)?
    @ObservationIgnored var onSelectionTranslationEnabledChange: ((Bool) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isRevertingHotKey = false
    @ObservationIgnored private var isRevertingTranslationHotKey = false
    @ObservationIgnored private var isRevertingPasteStackHotKey = false
    @ObservationIgnored private var isRevertingScreenshotHotKey = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.appLanguage = defaults
            .string(forKey: Keys.appLanguage)
            .flatMap(AppLanguagePreference.init(rawValue:))
            ?? .system

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

        let storedPasteStackKeyCode = defaults.integer(
            forKey: Keys.pasteStackHotKeyCode
        )
        let storedPasteStackModifiers = defaults.integer(
            forKey: Keys.pasteStackHotKeyModifiers
        )
        let storedPasteStackHotKey = HotKeyConfiguration(
            keyCode: UInt32(clamping: storedPasteStackKeyCode),
            carbonModifiers: UInt32(clamping: storedPasteStackModifiers)
        )
        self.pasteStackHotKey = storedPasteStackHotKey.isValid
            ? storedPasteStackHotKey
            : .pasteStackNextDefault

        let storedScreenshotKeyCode = defaults.integer(
            forKey: Keys.screenshotHotKeyCode
        )
        let storedScreenshotModifiers = defaults.integer(
            forKey: Keys.screenshotHotKeyModifiers
        )
        let storedScreenshotHotKey = HotKeyConfiguration(
            keyCode: UInt32(clamping: storedScreenshotKeyCode),
            carbonModifiers: UInt32(clamping: storedScreenshotModifiers)
        )
        self.screenshotHotKey = storedScreenshotHotKey.isValid
            ? storedScreenshotHotKey
            : .screenshotTranslationDefault

        // Auto-translation used to default on. Turn it off once for existing
        // installs as well as fresh ones, then respect the user's choice.
        if !defaults.bool(forKey: Keys.autoTranslateDefaultOffMigrated) {
            self.autoTranslateLatestOnOpen = false
            defaults.set(false, forKey: Keys.autoTranslateLatestOnOpen)
            defaults.set(true, forKey: Keys.autoTranslateDefaultOffMigrated)
        } else {
            self.autoTranslateLatestOnOpen = defaults.bool(
                forKey: Keys.autoTranslateLatestOnOpen
            )
        }

        let storedTrashRetention = defaults.integer(forKey: Keys.trashRetentionDays)
        self.trashRetentionDays = Self.trashRetentionOptions.contains(storedTrashRetention)
            ? storedTrashRetention
            : Self.defaultTrashRetentionDays

        let storedFallDuration = defaults.double(forKey: Keys.shelfCardFallDuration)
        self.shelfCardFallDuration = Self.shelfCardFallDurationOptions.contains(storedFallDuration)
            ? storedFallDuration
            : Self.defaultShelfCardFallDuration

        self.selectionTranslationEnabled = defaults.bool(
            forKey: Keys.selectionTranslationEnabled
        )
        self.panelCopyBehavior = defaults
            .string(forKey: Keys.panelCopyBehavior)
            .flatMap(CopyBehavior.init(rawValue:))
            ?? .hideImmediately
        self.shelfCopyBehavior = defaults
            .string(forKey: Keys.shelfCopyBehavior)
            .flatMap(CopyBehavior.init(rawValue:))
            ?? .stayOpen
        self.copyPlainTextOnly = defaults.bool(
            forKey: Keys.copyPlainTextOnly
        )
        if defaults.object(forKey: Keys.copyTranslationWhenReplacing) == nil {
            self.copyTranslationWhenReplacing = true
        } else {
            self.copyTranslationWhenReplacing = defaults.bool(
                forKey: Keys.copyTranslationWhenReplacing
            )
        }
        if defaults.object(forKey: Keys.liquidGlassEnabled) == nil {
            self.liquidGlassEnabled = true
        } else {
            self.liquidGlassEnabled = defaults.bool(
                forKey: Keys.liquidGlassEnabled
            )
        }

        if defaults.object(forKey: Keys.updateFeedURL) != nil {
            self.updateFeedURL = defaults.string(
                forKey: Keys.updateFeedURL
            ) ?? ""
        } else if let infoURL = Bundle.main.object(
            forInfoDictionaryKey: "HaoPasteUpdateFeedURL"
        ) as? String, !infoURL.isEmpty {
            self.updateFeedURL = infoURL
        } else {
            self.updateFeedURL = Self.defaultUpdateFeedURL
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

    func setPasteStackHotKeyRegistrationError(_ message: String?) {
        pasteStackHotKeyRegistrationError = message
    }

    func revertPasteStackHotKey(to configuration: HotKeyConfiguration) {
        guard pasteStackHotKey != configuration else { return }
        isRevertingPasteStackHotKey = true
        pasteStackHotKey = configuration
        isRevertingPasteStackHotKey = false
    }

    func resetPasteStackHotKeyToDefault() {
        pasteStackHotKey = .pasteStackNextDefault
    }

    func setScreenshotHotKeyRegistrationError(_ message: String?) {
        screenshotHotKeyRegistrationError = message
    }

    func revertScreenshotHotKey(to configuration: HotKeyConfiguration) {
        guard screenshotHotKey != configuration else { return }
        isRevertingScreenshotHotKey = true
        screenshotHotKey = configuration
        isRevertingScreenshotHotKey = false
    }

    func resetScreenshotHotKeyToDefault() {
        screenshotHotKey = .screenshotTranslationDefault
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
            launchAtLoginError = L(
                "无法更新登录项：%@",
                error.localizedDescription
            )
        }

        refreshLaunchAtLoginStatus()

        if enabled, service.status == .requiresApproval {
            launchAtLoginError = L("请在“系统设置 → 通用 → 登录项”中允许 HaoPaste 在登录时打开。")
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
