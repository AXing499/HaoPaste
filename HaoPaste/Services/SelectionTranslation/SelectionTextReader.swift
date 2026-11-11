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

        // Chromium/Electron apps expose their accessibility tree lazily. This
        // hint is ignored by apps that do not support it.
        AXUIElementSetAttributeValue(
            application,
            "AXEnhancedUserInterface" as CFString,
            kCFBooleanTrue
        )

        var roots: [AXUIElement] = []
        if let focused = focusedElement(of: application) {
            roots.append(focused)
        }
        if let systemFocused = focusedElement(
            of: AXUIElementCreateSystemWide()
        ), !roots.contains(where: { CFEqual($0, systemFocused) }) {
            roots.append(systemFocused)
        }

        for root in roots {
            if let text = text(from: root) {
                return text
            }
            if let text = text(inChildrenOf: root) {
                return text
            }
            if let text = text(inAncestorsOf: root) {
                return text
            }
        }

        return nil
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

    // MARK: - Focused elements

    private static func focusedElement(
        of application: AXUIElement
    ) -> AXUIElement? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                application,
                kAXFocusedUIElementAttribute as CFString,
                &value
            ) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return (value as! AXUIElement)
    }

    // MARK: - Selection extraction

    private static func text(from element: AXUIElement) -> String? {
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

    private static func text(
        inChildrenOf root: AXUIElement
    ) -> String? {
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var visited = Set<CFHashCode>()
        var visitedCount = 0

        while !queue.isEmpty, visitedCount < 80 {
            let (element, depth) = queue.removeFirst()
            let hash = CFHash(element)
            guard visited.insert(hash).inserted else { continue }
            visitedCount += 1

            if let text = text(from: element) {
                return text
            }

            guard depth < 3 else { continue }
            guard
                let children = elementArrayAttribute(
                    kAXChildrenAttribute as CFString,
                    from: element
                )
            else {
                continue
            }
            queue.append(contentsOf: children.map { ($0, depth + 1) })
        }

        return nil
    }

    private static func text(
        inAncestorsOf element: AXUIElement
    ) -> String? {
        var current: AXUIElement? = element
        var depth = 0

        while let element = current, depth < 4 {
            if let text = text(from: element) {
                return text
            }
            current = elementAttribute(
                kAXParentAttribute as CFString,
                from: element
            )
            depth += 1
        }

        return nil
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

    // MARK: - Attribute helpers

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

    private static func elementAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> AXUIElement? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private static func elementArrayAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            let value,
            CFGetTypeID(value) == CFArrayGetTypeID()
        else {
            return nil
        }
        return value as? [AXUIElement]
    }
}
