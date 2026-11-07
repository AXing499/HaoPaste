//
//  ExcludedApplication.swift
//  HaoPaste
//
//  An application whose clipboard contents should not be recorded.
//

import Foundation

struct ExcludedApplication: Codable, Hashable, Identifiable, Sendable {
    var bundleIdentifier: String?
    var name: String

    var id: String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }
        return "name:\(name.lowercased())"
    }

    init(bundleIdentifier: String?, name: String) {
        let trimmedIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bundleIdentifier = (trimmedIdentifier?.isEmpty == false) ? trimmedIdentifier : nil
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
