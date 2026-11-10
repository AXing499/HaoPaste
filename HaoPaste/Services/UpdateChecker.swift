//
//  UpdateChecker.swift
//  HaoPaste
//
//  Lightweight, opt-in update check against a small JSON manifest. The app
//  never downloads or installs an update automatically.
//

import AppKit
import Foundation

struct UpdateManifest: Decodable {
    let version: String
    let downloadURL: URL
    let notes: String?
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let htmlURL: URL
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
        case draft
        case prerelease
        case assets
    }
}

enum UpdateChecker {
    enum CheckError: LocalizedError {
        case invalidResponse
        case invalidFeed
        case noReleases

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return L("更新服务器返回了无效响应。")
            case .invalidFeed:
                return L("更新清单格式不正确。")
            case .noReleases:
                return L("这个仓库还没有发布版本。")
            }
        }
    }

    static func fetch(from url: URL) async throws -> UpdateManifest {
        guard url.scheme == "https" || url.scheme == "http" else {
            throw CheckError.invalidFeed
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )
        request.setValue(
            "HaoPaste/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CheckError.invalidResponse
        }
        if http.statusCode == 404 {
            throw CheckError.noReleases
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CheckError.invalidResponse
        }

        return try manifest(from: data)
    }

    /// Accepts either a GitHub Releases API payload or the small custom
    /// manifest documented in Docs/update-manifest-example.json.
    static func manifest(from data: Data) throws -> UpdateManifest {
        let decoder = JSONDecoder()
        if let release = try? decoder.decode(GitHubRelease.self, from: data) {
            guard !release.draft, !release.prerelease else {
                throw CheckError.noReleases
            }
            let download = release.assets.first {
                $0.name.lowercased().hasSuffix(".dmg")
            }?.browserDownloadURL ?? release.htmlURL
            return UpdateManifest(
                version: release.tagName,
                downloadURL: download,
                notes: release.body
            )
        }

        do {
            return try decoder.decode(UpdateManifest.self, from: data)
        } catch {
            throw CheckError.invalidFeed
        }
    }

    static func isNewer(version: String, than current: String) -> Bool {
        let lhs = normalized(version)
        let rhs = normalized(current)
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        return lhs.compare(rhs, options: .numeric) == .orderedDescending
    }

    private static func normalized(_ version: String) -> String {
        var value = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value.removeFirst()
        }
        return value
    }

    /// Turns the bilingual Markdown release body into a compact plain-text
    /// summary for the user's language. Custom JSON feeds that already contain
    /// plain text pass through unchanged.
    static func releaseNotesSummary(
        _ notes: String?,
        preferChinese: Bool = AppLanguage.isChinese
    ) -> String? {
        guard
            let raw = notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }

        let section = localizedChanges(in: raw, preferChinese: preferChinese) ?? raw
        let lines = plainText(from: section)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var summary = lines.prefix(14).joined(separator: "\n")
        if summary.count > 1_200 {
            summary = String(summary.prefix(1_200)) + "…"
        }
        return summary.isEmpty ? nil : summary
    }

    private static func localizedChanges(
        in notes: String,
        preferChinese: Bool
    ) -> String? {
        let changesMarker = notes.range(of: "## 本次变更")
            ?? notes.range(of: "## Changes")
        guard let changesMarker else { return nil }

        let changes = notes[changesMarker.lowerBound...]
        let languageMarker = preferChinese ? "### 中文" : "### English"
        guard let start = changes.range(of: languageMarker) else {
            return nil
        }

        let remainder = changes[start.upperBound...]
        let end = remainder.range(of: "### ")
            ?? remainder.range(of: "## ")
        return String(remainder[..<(end?.lowerBound ?? remainder.endIndex)])
    }

    private static func plainText(from markdown: String) -> String {
        var text = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        for token in ["**", "__", "`"] {
            text = text.replacingOccurrences(of: token, with: "")
        }

        let linkPattern = #"\[([^\]]+)\]\([^\)]+\)"#
        if let regex = try? NSRegularExpression(pattern: linkPattern) {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(
                in: text,
                range: range,
                withTemplate: "$1"
            )
        }

        return text
            .components(separatedBy: .newlines)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- ") {
                    return "• " + trimmed.dropFirst(2)
                }
                return trimmed
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    static func presentUpdate(
        _ manifest: UpdateManifest,
        currentVersion: String
    ) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("发现新版本 %@", manifest.version)
        alert.informativeText = [
            L("当前版本：%@", currentVersion),
            releaseNotesSummary(manifest.notes)
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("下载更新"))
        alert.addButton(withTitle: L("稍后"))

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(manifest.downloadURL)
        }
    }

    @MainActor
    static func presentNoUpdate(currentVersion: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("已是最新版本")
        alert.informativeText = L("当前版本：%@", currentVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("好"))
        alert.runModal()
    }

    @MainActor
    static func presentError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("检查更新失败")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("好"))
        alert.runModal()
    }
}
