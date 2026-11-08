//
//  ImageSavePanel.swift
//  HaoPaste
//
//  Shared "save image as PNG" flow used by rows and the preview overlay.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
enum ImageSavePanel {
    @discardableResult
    static func present(
        imageURL: URL,
        suggestedName: String = "HaoPaste-图片.png"
    ) -> Bool {
        let panel = NSSavePanel()
        panel.title = "保存图片"
        panel.prompt = "保存"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName

        guard panel.runModal() == .OK, let destination = panel.url else {
            return false
        }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: imageURL, to: destination)
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法保存图片"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "好")
            alert.runModal()
            return false
        }
    }
}
