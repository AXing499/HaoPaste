//
//  GlobalHotKey.swift
//  HaoPaste
//
//  Carbon is still the most reliable way to register a system-wide hotkey
//  without requiring Accessibility permission.
//

import AppKit
import Carbon.HIToolbox

final class GlobalHotKey {
    enum RegistrationError: LocalizedError {
        case eventHandler(OSStatus)
        case registration(OSStatus)

        var errorDescription: String? {
            switch self {
            case .eventHandler:
                return "无法安装全局快捷键事件处理器。"
            case .registration:
                return "这个快捷键可能已被其他应用占用，请换一个组合。"
            }
        }

        var failureReason: String? {
            switch self {
            case let .eventHandler(status):
                return "InstallEventHandler 返回错误码 \(status)。"
            case let .registration(status):
                return "RegisterEventHotKey 返回错误码 \(status)。"
            }
        }
    }

    private static let signature: OSType = 0x48415053 // 'HAPS'
    private static let hotKeyID: UInt32 = 1

    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) throws {
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
            throw RegistrationError.eventHandler(status)
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

        guard registerStatus == noErr else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
                self.eventHandlerRef = nil
            }
            throw RegistrationError.registration(registerStatus)
        }
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
