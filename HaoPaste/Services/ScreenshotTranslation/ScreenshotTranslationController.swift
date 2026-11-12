//
//  ScreenshotTranslationController.swift
//  HaoPaste
//
//  Region capture -> local OCR -> optional translation.
//

import AppKit

@MainActor
final class ScreenshotTranslationController {
    private let manager: ClipboardManager
    private let snippetManager: SnippetManager
    private let ocrService: OCRService
    private let quickTranslationController: QuickTranslationPanelController

    private let selectionController = ScreenshotSelectionController()
    private let ocrPanelController: ScreenshotOCRPanelController

    var isSelecting: Bool {
        selectionController.isSelecting
    }

    init(
        manager: ClipboardManager,
        snippetManager: SnippetManager,
        ocrService: OCRService,
        quickTranslationController: QuickTranslationPanelController
    ) {
        self.manager = manager
        self.snippetManager = snippetManager
        self.ocrService = ocrService
        self.quickTranslationController = quickTranslationController
        self.ocrPanelController = ScreenshotOCRPanelController(
            manager: manager,
            service: ocrService
        )
    }

    func beginCapture() {
        guard !selectionController.isSelecting else { return }
        guard let screen = screenUnderMouse() else { return }

        selectionController.begin(on: screen) { [weak self] rect, targetScreen in
            self?.capture(rect: rect, on: targetScreen)
        } onCancel: {}
    }

    private func capture(rect: NSRect, on screen: NSScreen) {
        Task { @MainActor [weak self] in
            // Let the selection overlay disappear before capturing.
            try? await Task.sleep(for: .milliseconds(80))
            guard let self else { return }

            do {
                let image = try await ScreenshotCaptureService.capture(
                    rect: rect,
                    on: screen
                )
                let imageURL = try ScreenshotCaptureService.writePNG(image)
                self.presentOCR(imageURL: imageURL, image: image)
            } catch {
                self.presentCaptureError(error)
            }
        }
    }

    private func presentOCR(imageURL: URL, image: CGImage) {
        ocrPanelController.present(
            imageURL: imageURL,
            width: image.width,
            height: image.height,
            onTranslateText: { [weak self] text, title in
                self?.quickTranslationController.present(
                    text: text,
                    title: title
                )
            },
            onSaveSnippet: { [weak self] text in
                guard let self, !text.isEmpty else { return }
                _ = self.snippetManager.create(
                    title: L("截图文字"),
                    content: text
                )
            },
            onHide: {}
        )
    }

    private func presentCaptureError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("无法截取屏幕")
        alert.informativeText = L(
            "请在「系统设置 → 隐私与安全性 → 屏幕录制」中允许 HaoPaste，然后重试；如仍失败，请重新打开 HaoPaste。当前 ad-hoc 签名版本在更新后可能需要重新授权。"
        )
        alert.addButton(withTitle: L("打开系统设置"))
        alert.addButton(withTitle: L("取消"))

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            ) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func screenUnderMouse() -> NSScreen? {
        NSScreen.screens.first {
            $0.frame.contains(NSEvent.mouseLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first
    }
}
