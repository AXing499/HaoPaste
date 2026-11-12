//
//  ScreenshotCaptureService.swift
//  HaoPaste
//
//  Captures the user-selected screen region for local OCR and translation.
//

import AppKit
import ScreenCaptureKit

@MainActor
enum ScreenshotCaptureService {
    enum CaptureError: LocalizedError {
        case displayUnavailable
        case captureFailed
        case cropFailed

        var errorDescription: String? {
            switch self {
            case .displayUnavailable:
                return L("无法找到当前屏幕。")
            case .captureFailed:
                return L("无法截取屏幕。请检查「屏幕录制」权限。")
            case .cropFailed:
                return L("无法裁剪截图区域。")
            }
        }
    }

    static func capture(rect: NSRect, on screen: NSScreen) async throws -> CGImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw CaptureError.captureFailed
        }

        let screenNumber = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber
        let displayID = screenNumber?.uint32Value

        guard
            let displayID,
            let display = content.displays.first(where: {
                $0.displayID == displayID
            })
        else {
            throw CaptureError.displayUnavailable
        }

        let filter = SCContentFilter(
            display: display,
            excludingWindows: []
        )
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false

        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            throw CaptureError.captureFailed
        }

        let scaleX = CGFloat(image.width) / screen.frame.width
        let scaleY = CGFloat(image.height) / screen.frame.height
        let localRect = CGRect(
            x: (rect.minX - screen.frame.minX) * scaleX,
            y: (screen.frame.maxY - rect.maxY) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).integral

        let clamped = localRect.intersection(
            CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        guard !clamped.isEmpty, let cropped = image.cropping(to: clamped) else {
            throw CaptureError.cropFailed
        }
        return cropped
    }

    static func writePNG(_ image: CGImage) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HaoPasteScreenshots", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent(
            "screenshot-\(UUID().uuidString).png"
        )
        let representation = NSBitmapImageRep(cgImage: image)
        guard
            let data = representation.representation(
                using: .png,
                properties: [:]
            )
        else {
            throw CaptureError.captureFailed
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}
