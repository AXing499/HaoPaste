//
//  PasteEventSender.swift
//  HaoPaste
//
//  Sends an explicit Command-V only after the user starts an action that
//  requires pasting into another app.
//

import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
enum PasteEventSender {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func sendCommandV() {
        guard isTrusted else { return }
        guard
            NSWorkspace.shared.frontmostApplication?.processIdentifier
                != ProcessInfo.processInfo.processIdentifier
        else {
            return
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCodeV: CGKeyCode = 0x09

        let down = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeV,
            keyDown: true
        )
        down?.flags = .maskCommand

        let up = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCodeV,
            keyDown: false
        )
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
