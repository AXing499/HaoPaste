//
//  DebugRenderer.swift
//  HaoPaste
//
//  DEBUG-only off-screen renderer used for visual QA and README screenshots.
//

#if DEBUG
import AppKit
import SwiftUI

@MainActor
enum DebugRenderer {
    private static var renderWindow: NSWindow?

    static func renderPanel(
        manager: ClipboardManager,
        to url: URL,
        completion: @escaping @MainActor () -> Void
    ) {
        let state = PanelViewState()
        let firstItemID = manager.filteredItems(query: "", filter: .all).first?.id
        state.prepareForPresentation(firstItemID: firstItemID)

        let isDark = ProcessInfo.processInfo.environment["HAOPASTE_RENDER_APPEARANCE"] == "dark"

        let backgroundColors: [Color] = isDark
            ? [
                Color(nsColor: NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.34, alpha: 1)),
                Color(nsColor: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.16, alpha: 1))
            ]
            : [
                Color(nsColor: NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.97, alpha: 1)),
                Color(nsColor: NSColor(calibratedRed: 0.70, green: 0.76, blue: 0.86, alpha: 1))
            ]

        let content = ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.accentColor.opacity(isDark ? 0.35 : 0.16))
                .frame(width: 560, height: 560)
                .blur(radius: 120)
                .offset(x: 250, y: -240)

            ContentView(state: state, onCopy: { _ in })
                .environment(manager)
        }
        .frame(width: Theme.windowSize.width, height: Theme.windowSize.height)

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: Theme.windowSize)

        let window = RenderWindow(
            contentRect: NSRect(origin: .zero, size: Theme.windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.contentView = hostingView

        if ProcessInfo.processInfo.environment["HAOPASTE_RENDER_APPEARANCE"] == "dark" {
            window.appearance = NSAppearance(named: .darkAqua)
        }
        if let screen = NSScreen.main {
            // Keep the test window away from the cursor so rows render in their
            // idle state rather than a hover state.
            let origin = NSPoint(
                x: screen.visibleFrame.minX + 20,
                y: screen.visibleFrame.minY + 20
            )
            window.setFrameOrigin(origin)
        }

        window.orderFrontRegardless()
        renderWindow = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            hostingView.layoutSubtreeIfNeeded()

            guard
                let representation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
            else {
                NSLog("HaoPaste: could not allocate the panel preview")
                window.orderOut(nil)
                renderWindow = nil
                completion()
                return
            }

            hostingView.cacheDisplay(in: hostingView.bounds, to: representation)

            guard let pngData = representation.representation(using: .png, properties: [:]) else {
                NSLog("HaoPaste: could not encode the panel preview")
                window.orderOut(nil)
                renderWindow = nil
                completion()
                return
            }

            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try pngData.write(to: url, options: .atomic)
                NSLog("HaoPaste: wrote panel preview to \(url.path)")
            } catch {
                NSLog("HaoPaste: could not write panel preview — \(error.localizedDescription)")
            }

            window.orderOut(nil)
            renderWindow = nil
            completion()
        }
    }
}

private final class RenderWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
#endif
