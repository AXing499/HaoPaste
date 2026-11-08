//
//  AppPaths.swift
//  HaoPaste
//
//  One storage root shared by history, images, snippets and settings.
//

import Foundation

enum AppPaths {
    static var storageDirectory: URL {
        let arguments = ProcessInfo.processInfo.arguments
        if let storageFlagIndex = arguments.firstIndex(of: "--storage"),
           arguments.indices.contains(storageFlagIndex + 1) {
            return URL(
                fileURLWithPath: arguments[storageFlagIndex + 1],
                isDirectory: true
            )
        }

        if let override = ProcessInfo.processInfo.environment["HAOPASTE_STORAGE_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        return applicationSupport.appendingPathComponent("HaoPaste", isDirectory: true)
    }
}
