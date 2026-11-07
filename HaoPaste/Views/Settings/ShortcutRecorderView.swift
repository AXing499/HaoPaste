//
//  ShortcutRecorderView.swift
//  HaoPaste
//
//  Click-to-record global shortcut control for the settings window.
//

import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    let configuration: HotKeyConfiguration
    let registrationError: String?
    let onRecord: (HotKeyConfiguration) -> Void
    let onReset: () -> Void

    @State private var isRecording = false
    @State private var validationMessage: String?
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isRecording ? "record.circle" : "keyboard")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isRecording ? Color.accentColor : .secondary)

                    Text(isRecording ? "请按下新的快捷键…" : configuration.displayString)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(isRecording ? Color.accentColor : .primary)
                        .monospacedDigit()

                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            isRecording
                                ? Color.accentColor.opacity(0.08)
                                : Color.primary.opacity(0.05)
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isRecording
                                ? Color.accentColor.opacity(0.45)
                                : Color.primary.opacity(0.08),
                            lineWidth: 0.5
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(isRecording ? "按下新的快捷键，按 esc 取消" : "点击后按下新的快捷键")

            if let message = validationMessage ?? registrationError {
                Text(message)
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 310, alignment: .trailing)
            }

            if configuration != .default || registrationError != nil {
                Button("恢复默认（\(HotKeyConfiguration.default.displayString)）", action: onReset)
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }

        validationMessage = nil
        isRecording = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // esc cancels recording
                stopRecording()
                return nil
            }

            let modifiers = HotKeyConfiguration.carbonModifiers(
                from: event.modifierFlags
            )
            let candidate = HotKeyConfiguration(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: modifiers
            )

            guard candidate.hasPrimaryModifier else {
                validationMessage = "请至少按下 ⌘、⌥ 或 ⌃ 中的一个。"
                return nil
            }

            validationMessage = nil
            onRecord(candidate)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}
