//
//  GlobalHotKey.swift
//  HaoPaste
//
//  Carbon is still the most reliable way to register a system-wide hotkey
//  without requiring Accessibility permission.
//

import AppKit
import Carbon.HIToolbox

@MainActor
final class GlobalHotKey {
    private static let signature: OSType = 0x48415053 // 'HAPS'
    private static let hotKeyID: UInt32 = 1

    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard status == noErr else {
            NSLog("HaoPaste: could not install hotkey event handler (\(status))")
            return
        }

        let identifier = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            NSLog("HaoPaste: could not register global hotkey (\(registerStatus))")
        }
    }

    /// ⌥⌘V — the panel can be summoned from any app.
    static func makeDefault(action: @escaping () -> Void) -> GlobalHotKey {
        GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | optionKey),
            action: action
        )
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func invoke() {
        action()
    }

    private static let eventHandler: EventHandlerUPP = { _, event, userData in
        guard
            let event,
            let userData
        else {
            return OSStatus(eventNotHandledErr)
        }

        var identifier = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &identifier
        )

        guard status == noErr, identifier.signature == GlobalHotKey.signature else {
            return OSStatus(eventNotHandledErr)
        }

        let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
        hotKey.invoke()
        return noErr
    }
}
