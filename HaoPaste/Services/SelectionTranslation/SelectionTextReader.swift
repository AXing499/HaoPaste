//
//  SelectionTextReader.swift
//  HaoPaste
//
//  Reads the focused app's selected text through the Accessibility API.
//  It never copies through the pasteboard, so it cannot steal ⌘C.
//

import AppKit
import ApplicationServices
import Carbon

enum SelectionTextReader {
    static func selectedText(in app: NSRunningApplication) -> String? {
        let application = AXUIElementCreateApplication(app.processIdentifier)

        var focusedValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                application,
                kAXFocusedUIElementAttribute as CFString,
                &focusedValue
            ) == .success,
            let focusedValue,
            CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else {
            return nil
        }

        let element = focusedValue as! AXUIElement

        if let text = stringAttribute(
            kAXSelectedTextAttribute as CFString,
            from: element
        ) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return text
            }
        }

        return selectedTextFromRange(element)
    }

    static func isSecureInputEnabled() -> Bool {
        IsSecureEventInputEnabled()
    }

    static func isFullscreen(_ app: NSRunningApplication) -> Bool {
        guard
            let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return false
        }

        let screenFrames = NSScreen.screens.map(\.frame)
        for info in windows {
            guard
                let owner = info[kCGWindowOwnerPID as String] as? NSNumber,
                owner.int32Value == app.processIdentifier,
                let layer = info[kCGWindowLayer as String] as? NSNumber,
                layer.intValue == 0,
                let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                let rect = CGRect(dictionaryRepresentation: bounds)
            else {
                continue
            }

            if screenFrames.contains(where: {
                abs($0.width - rect.width) < 4
                    && abs($0.height - rect.height) < 4
            }) {
                return true
            }
        }

        return false
    }

    private static func stringAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> String? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, attribute, &value) == .success
        else {
            return nil
        }
        return value as? String
    }

    private static func selectedTextFromRange(
        _ element: AXUIElement
    ) -> String? {
        var rangeValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                &rangeValue
            ) == .success,
            let rangeValue,
            CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var range = CFRange()
        guard
            AXValueGetValue(rangeValue as! AXValue, .cfRange, &range),
            range.length > 0
        else {
            return nil
        }

        var textValue: CFTypeRef?
        guard
            AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &textValue
            ) == .success,
            let text = textValue as? String,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        return text
    }
}
