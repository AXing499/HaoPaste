//
//  OnboardingWindowController.swift
//  HaoPaste
//
//  First-launch welcome and a refresher from Settings → About.
//

import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎使用 HaoPaste"
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed

        super.init(window: window)

        window.contentViewController = NSHostingController(
            rootView: OnboardingView { [weak self] in
                self?.finish()
            }
        )
        window.delegate = self
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        window?.orderOut(nil)
        onFinish()
    }

    func windowWillClose(_ notification: Notification) {
        onFinish()
    }
}

private struct OnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 5)

                VStack(alignment: .leading, spacing: 5) {
                    Text("欢迎使用 HaoPaste")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("菜单栏里的剪贴板历史，随时呼出、随手复制。")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 26)

            VStack(spacing: 14) {
                OnboardingRow(
                    symbol: "menubar.rectangle",
                    title: "菜单栏常驻",
                    text: "HaoPaste 不会出现在 Dock；请在菜单栏找到剪贴板图标。"
                )
                OnboardingRow(
                    symbol: "keyboard",
                    title: "随时呼出",
                    text: "按 ⌥⌘V 打开面板，也可以点击菜单栏图标。"
                )
                OnboardingRow(
                    symbol: "rectangle.topthird.inset.filled",
                    title: "边缘挂架",
                    text: "把鼠标移到屏幕顶部 / 左侧 / 右侧中间，挂架会自动展开。"
                )
                OnboardingRow(
                    symbol: "cursorarrow.click.2",
                    title: "卡片操作",
                    text: "点击卡片复制；悬停可预览、翻译或提取文字；点击夹子删除。"
                )
            }

            Spacer(minLength: 18)

            HStack {
                Text("以后可以在设置 → 关于中再次查看")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("开始使用") {
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 620, height: 470)
        .background(.regularMaterial)
    }
}

private struct OnboardingRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Text(text)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
