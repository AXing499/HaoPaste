//
//  OCRService.swift
//  HaoPaste
//
//  On-device image text recognition backed by Vision.
//

import Foundation
import ImageIO
import Observation
import Vision

@MainActor
@Observable
final class OCRService {
    enum Phase: Equatable {
        case idle
        case recognizing
        case success
        case empty
        case failed
    }

    typealias Recognizer = @Sendable (URL) async throws -> String

    var isPresenting = false
    var sourceTitle = ""
    var sourceImageURL: URL?
    var text = ""
    var phase: Phase = .idle
    var errorMessage: String?

    @ObservationIgnored private let recognizer: Recognizer
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var sourceItemID: UUID?
    @ObservationIgnored private var cache: [UUID: String] = [:]

    init(recognizer: @escaping Recognizer = { @Sendable url in
        try await VisionTextRecognizer.recognize(url: url)
    }) {
        self.recognizer = recognizer
    }

    // MARK: - Presentation

    func present(item: ClipboardItem, imageURL: URL) {
        task?.cancel()

        sourceItemID = item.id
        sourceTitle = item.displayTitle
        sourceImageURL = imageURL
        isPresenting = true
        errorMessage = nil

        if let cached = cache[item.id] {
            text = cached
            phase = cached.isEmpty ? .empty : .success
            return
        }

        text = ""
        recognize()
    }

    func recognize(force: Bool = false) {
        guard let imageURL = sourceImageURL, let itemID = sourceItemID else {
            return
        }

        if !force, let cached = cache[itemID] {
            text = cached
            phase = cached.isEmpty ? .empty : .success
            return
        }

        task?.cancel()
        phase = .recognizing
        errorMessage = nil

        task = Task { [weak self, recognizer] in
            do {
                let result = try await recognizer(imageURL)
                guard !Task.isCancelled, let self else { return }

                let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                text = trimmed
                phase = trimmed.isEmpty ? .empty : .success
                cache[itemID] = trimmed
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, let self else { return }
                phase = .failed
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateText(_ value: String) {
        text = value

        if let sourceItemID {
            cache[sourceItemID] = value
        }

        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .success
        }
    }

    func close() {
        task?.cancel()
        task = nil
        isPresenting = false
        phase = .idle
        errorMessage = nil
    }

    /// Used by tests and visual QA.
    func waitForCurrentRecognition() async {
        await task?.value
    }

    #if DEBUG
    func seedPreview(
        sourceTitle: String,
        imageURL: URL?,
        text: String
    ) {
        task?.cancel()
        self.sourceTitle = sourceTitle
        self.sourceImageURL = imageURL
        self.text = text
        self.phase = text.isEmpty ? .empty : .success
        self.isPresenting = true
        self.errorMessage = nil
    }
    #endif
}

enum VisionTextRecognizer {
    static func recognize(url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try recognizeSynchronously(url: url)
        }.value
    }

    private static func recognizeSynchronously(url: URL) throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw OCRError.invalidImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4_096
        ]

        let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) ?? CGImageSourceCreateImageAtIndex(source, 0, nil)

        guard let image else {
            throw OCRError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }

        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: .up,
            options: [:]
        )
        try handler.perform([request])

        let observations = request.results ?? []
        let sorted = observations.sorted { first, second in
            let firstY = first.boundingBox.midY
            let secondY = second.boundingBox.midY

            if abs(firstY - secondY) > 0.02 {
                return firstY > secondY
            }
            return first.boundingBox.minX < second.boundingBox.minX
        }

        let lines = sorted.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法读取这张图片。"
        }
    }
}
