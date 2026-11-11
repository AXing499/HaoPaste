//
//  SelectionTranslationAccess.swift
//  HaoPaste
//
//  Accessibility permission helpers for the optional selection translator.
//

import AppKit
import ApplicationServices

enum SelectionTranslationAccess {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func request() -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
