//
//  PasteStackController.swift
//  HaoPaste
//
//  Sequential paste queue started from a multi-selection in the main panel.
//

import AppKit
import SwiftUI

@MainActor
final class PasteStackController: NSObject {
    private let manager: ClipboardManager
    private let hud = PasteStackHUDController()

    private(set) var isActive = false
    private var items: [ClipboardItem] = []
    private var index = 0
    private var targetApplication: NSRunningApplication?
    private var shortcutDisplay = HotKeyConfiguration.pasteStackNextDefault.displayString
    private var hideHUDTask: DispatchWorkItem?

    init(manager: ClipboardManager) {
        self.manager = manager
        super.init()
    }

    // MARK: - Lifecycle

    func start(
        items: [ClipboardItem],
        targetApplication: NSRunningApplication?,
        shortcutDisplay: String
    ) {
        guard !items.isEmpty else { return }

        stop()
        self.items = items
        self.targetApplication = targetApplication
        self.shortcutDisplay = shortcutDisplay
        index = 0
        isActive = true
        hideHUDTask?.cancel()
        hideHUDTask = nil

        pasteCurrentItem()
    }

    func stop() {
        hideHUDTask?.cancel()
        hideHUDTask = nil
        isActive = false
        targetApplication = nil
        items = []
        index = 0
        hud.hide()
    }

    private func finish() {
        let count = items.count
        isActive = false
        targetApplication = nil
        items = []
        index = 0

        hud.showFinished(total: count)

        let task = DispatchWorkItem { [weak self] in
            self?.hud.hide()
        }
        hideHUDTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: task)
    }

    // MARK: - Queue

    func advance() {
        guard isActive else { return }

        if index + 1 < items.count {
            index += 1
            pasteCurrentItem()
        } else {
            finish()
        }
    }

    private func pasteCurrentItem() {
        guard isActive, index < items.count else { return }

        let item = items[index]
        guard manager.copyToPasteboard(item) else {
            stop()
            NSSound.beep()
            return
        }

        let autoPastes = PasteEventSender.isTrusted
        hud.show(
            current: index + 1,
            total: items.count,
            shortcut: shortcutDisplay,
            autoPastes: autoPastes,
            animated: index == 0
        ) { [weak self] in
            self?.stop()
        }

        let expectedIndex = index
        if autoPastes {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.performAutoPaste(
                    expectedIndex: expectedIndex,
                    attempt: 0
                )
            }
        }

        if index == items.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard
                    let self,
                    self.isActive,
                    self.index == expectedIndex
                else {
                    return
                }
                self.finish()
            }
        }
    }

    private func performAutoPaste(expectedIndex: Int, attempt: Int) {
        guard
            isActive,
            index == expectedIndex,
            PasteEventSender.isTrusted
        else {
            return
        }

        let modifiers = NSEvent.modifierFlags.intersection([
            .command, .control, .option, .shift
        ])
        guard modifiers.isEmpty else {
            guard attempt < 20 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.performAutoPaste(
                    expectedIndex: expectedIndex,
                    attempt: attempt + 1
                )
            }
            return
        }

        activateTargetAndPaste(expectedIndex: expectedIndex)
    }

    private func activateTargetAndPaste(expectedIndex: Int) {
        guard
            isActive,
            index == expectedIndex,
            PasteEventSender.isTrusted,
            let targetApplication,
            !targetApplication.isTerminated
        else {
            return
        }

        let frontmost = NSWorkspace.shared.frontmostApplication
        guard
            frontmost == nil
                || frontmost?.processIdentifier == targetApplication.processIdentifier
                || frontmost?.processIdentifier
                    == ProcessInfo.processInfo.processIdentifier
        else {
            // The user switched to another app; do not steal focus.
            return
        }

        // Activate even when the app is already frontmost: a nonactivating
        // HaoPaste HUD can be the key window while another app is frontmost.
        targetApplication.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard
                let self,
                self.isActive,
                self.index == expectedIndex
            else {
                return
            }
            PasteEventSender.sendCommandV()
        }
    }
}

// MARK: - HUD

@MainActor
private final class PasteStackHUDController {
    private let panel: PasteStackHUDPanel

    private static let size = NSSize(width: 300, height: 58)

    init() {
        self.panel = PasteStackHUDPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .ignoresCycle
        ]
    }

    func show(
        current: Int,
        total: Int,
        shortcut: String,
        autoPastes: Bool,
        animated: Bool = true,
        onStop: @escaping () -> Void
    ) {
        let view = PasteStackHUDView(
            current: current,
            total: total,
            shortcut: shortcut,
            autoPastes: autoPastes,
            isFinished: false,
            onStop: onStop
        )
        present(view, animate: animated)
    }

    func showFinished(total: Int) {
        let view = PasteStackHUDView(
            current: total,
            total: total,
            shortcut: HotKeyConfiguration.pasteStackNextDefault.displayString,
            autoPastes: false,
            isFinished: true,
            onStop: {}
        )
        present(view, animate: false)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    private func present<V: View>(_ view: V, animate: Bool = true) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: Self.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView

        let screen = NSScreen.screens.first {
            $0.frame.contains(NSEvent.mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first
        if let screen {
            let frame = NSRect(
                x: (screen.visibleFrame.midX - Self.size.width / 2).rounded(.down),
                y: (screen.visibleFrame.minY + 24).rounded(.down),
                width: Self.size.width,
                height: Self.size.height
            )
            panel.setFrame(frame, display: false)
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = animate && !reduceMotion ? 0 : 1
        panel.orderFrontRegardless()

        if animate, !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: 0.16, 1, 0.3, 1
                )
                panel.animator().alphaValue = 1
            }
        }
    }
}

private final class PasteStackHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct PasteStackHUDView: View {
    let current: Int
    let total: Int
    let shortcut: String
    let autoPastes: Bool
    let isFinished: Bool
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isFinished ? "checkmark.circle.fill" : "list.number")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(isFinished ? Color.accentColor : Color.primary)
                .frame(width: 26, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    isFinished
                        ? L("连续粘贴完成")
                        : L("连续粘贴 %d / %d", current, total)
                )
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))

                Text(subtitle)
                    .font(.system(size: 9.5, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !isFinished {
                Button(L("结束"), action: onStop)
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background {
                        Capsule()
                            .fill(Color.primary.opacity(0.05))
                    }
                    .contentShape(Capsule())
                    .help(L("结束连续粘贴"))
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 300, height: 58)
        .background(.regularMaterial)
        .background(Theme.popoverBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: Theme.hairline)
        }
    }

    private var subtitle: String {
        if isFinished {
            return L("已粘贴 %d 项", total)
        }
        if autoPastes {
            return L("%@ 下一项 · 自动粘贴", shortcut)
        }
        return L("已复制 · 按 ⌘V 粘贴 · %@ 下一项", shortcut)
    }
}
