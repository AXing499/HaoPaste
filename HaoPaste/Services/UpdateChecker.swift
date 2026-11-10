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

enum UpdateChecker {
    enum CheckError: LocalizedError {
        case invalidResponse
        case invalidFeed

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "更新服务器返回了无效响应。"
            case .invalidFeed:
                return "更新清单格式不正确。"
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

        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else {
            throw CheckError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(UpdateManifest.self, from: data)
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

    @MainActor
    static func presentUpdate(
        _ manifest: UpdateManifest,
        currentVersion: String
    ) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(manifest.version)"
        alert.informativeText = [
            "当前版本：\(currentVersion)",
            manifest.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "下载更新")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(manifest.downloadURL)
        }
    }

    @MainActor
    static func presentNoUpdate(currentVersion: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "已是最新版本"
        alert.informativeText = "当前版本：\(currentVersion)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @MainActor
    static func presentError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
