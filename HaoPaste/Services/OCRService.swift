//
//  OCRService.swift
//  HaoPaste
//
//  On-device image text recognition backed by Vision, with a small local cache.
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

    struct BatchEntry: Identifiable, Equatable {
        let id: UUID
        let cacheKey: String
        let title: String
        let imageURL: URL
        var text: String
        var phase: Phase
        var errorMessage: String?
    }

    typealias Recognizer = @Sendable (URL, OCRRecognitionLanguage) async throws -> String

    // MARK: - Single image state

    var isPresenting = false
    var isBatchMode = false
    var sourceTitle = ""
    var sourceImageURL: URL?
    var text = ""
    var phase: Phase = .idle
    var errorMessage: String?

    // MARK: - Batch state

    var batchEntries: [BatchEntry] = []
    var batchProgressCurrent = 0
    var batchProgressTotal = 0

    var recognitionLanguage: OCRRecognitionLanguage {
        didSet {
            defaults.set(recognitionLanguage.rawValue, forKey: Keys.recognitionLanguage)
        }
    }

    @ObservationIgnored private let recognizer: Recognizer
    @ObservationIgnored private let cacheStore: OCRCacheStoring
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var sourceCacheKey: String?

    private enum Keys {
        static let recognitionLanguage = "ocr.recognitionLanguage"
    }

    init(
        recognizer: @escaping Recognizer = { @Sendable url, language in
            try await VisionTextRecognizer.recognize(url: url, language: language)
        },
        cache: OCRCacheStoring? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.recognizer = recognizer
        self.cacheStore = cache ?? OCRDiskCache()
        self.defaults = defaults
        self.recognitionLanguage = defaults.string(forKey: Keys.recognitionLanguage)
            .flatMap(OCRRecognitionLanguage.init(rawValue:)) ?? .automatic
    }

    // MARK: - Single image

    func present(item: ClipboardItem, imageURL: URL) {
        task?.cancel()

        isBatchMode = false
        batchEntries = []
        batchProgressCurrent = 0
        batchProgressTotal = 0

        sourceTitle = item.displayTitle
        sourceImageURL = imageURL
        isPresenting = true
        errorMessage = nil

        sourceCacheKey = cacheKey(for: item)
        if let cached = sourceCacheKey.flatMap(cacheStore.load(key:)) {
            text = cached
            phase = cached.isEmpty ? .empty : .success
            return
        }

        text = ""
        recognize()
    }

    func recognize(force: Bool = false) {
        guard let imageURL = sourceImageURL, let cacheKey = sourceCacheKey else {
            return
        }

        if !force, let cached = cacheStore.load(key: cacheKey) {
            text = cached
            phase = cached.isEmpty ? .empty : .success
            return
        }

        task?.cancel()
        phase = .recognizing
        errorMessage = nil

        let language = recognitionLanguage
        task = Task { [weak self, recognizer] in
            do {
                let result = try await recognizer(imageURL, language)
                guard !Task.isCancelled, let self else { return }

                let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                text = trimmed
                phase = trimmed.isEmpty ? .empty : .success
                cacheStore.save(trimmed, key: cacheKey)
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

        if let sourceCacheKey {
            cacheStore.save(value, key: sourceCacheKey)
        }

        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .success
        }
    }

    // MARK: - Batch

    func presentBatch(items: [(ClipboardItem, URL)]) {
        guard !items.isEmpty else { return }

        task?.cancel()
        isPresenting = true
        isBatchMode = true
        sourceTitle = ""
        sourceImageURL = nil
        text = ""
        phase = .idle
        errorMessage = nil

        batchEntries = items.enumerated().map { index, pair in
            let (item, imageURL) = pair
            let key = cacheKey(for: item)
            let cached = cacheStore.load(key: key)
            let title = items.count > 1
                ? "\(item.displayTitle) \(index + 1)"
                : item.displayTitle

            return BatchEntry(
                id: item.id,
                cacheKey: key,
                title: title,
                imageURL: imageURL,
                text: cached ?? "",
                phase: cached == nil
                    ? .idle
                    : (cached?.isEmpty == true ? .empty : .success),
                errorMessage: nil
            )
        }

        batchProgressTotal = batchEntries.count
        batchProgressCurrent = batchEntries.filter { $0.phase == .success }.count
        recognizeBatch()
    }

    func recognizeBatch(force: Bool = false) {
        guard isBatchMode, !batchEntries.isEmpty else { return }

        task?.cancel()
        batchProgressTotal = batchEntries.count
        batchProgressCurrent = force
            ? 0
            : batchEntries.filter { $0.phase == .success }.count

        let language = recognitionLanguage
        let indices = batchEntries.indices.filter { index in
            force || batchEntries[index].phase != .success
        }

        task = Task { [weak self, recognizer] in
            for index in indices {
                guard !Task.isCancelled, let self else { return }

                batchEntries[index].phase = .recognizing
                batchEntries[index].errorMessage = nil

                do {
                    let result = try await recognizer(
                        batchEntries[index].imageURL,
                        language
                    )
                    guard !Task.isCancelled else { return }

                    let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    batchEntries[index].text = trimmed
                    batchEntries[index].phase = trimmed.isEmpty ? .empty : .success
                    cacheStore.save(trimmed, key: batchEntries[index].cacheKey)
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    batchEntries[index].phase = .failed
                    batchEntries[index].errorMessage = error.localizedDescription
                }

                batchProgressCurrent += 1
            }
        }
    }

    func openBatchEntry(id: UUID) {
        guard let entry = batchEntries.first(where: { $0.id == id }) else {
            return
        }

        task?.cancel()
        isBatchMode = false
        batchEntries = []
        batchProgressCurrent = 0
        batchProgressTotal = 0

        sourceTitle = entry.title
        sourceImageURL = entry.imageURL
        text = entry.text
        phase = entry.phase == .recognizing
            ? (entry.text.isEmpty ? .idle : .success)
            : entry.phase
        errorMessage = entry.errorMessage
        sourceCacheKey = entry.cacheKey
        isPresenting = true
    }

    func updateBatchText(id: UUID, text value: String) {
        guard let index = batchEntries.firstIndex(where: { $0.id == id }) else {
            return
        }

        batchEntries[index].text = value
        cacheStore.save(value, key: batchEntries[index].cacheKey)

        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            batchEntries[index].phase = .success
        }
    }

    // MARK: - Lifecycle

    func close() {
        task?.cancel()
        task = nil
        isPresenting = false
        isBatchMode = false
        phase = .idle
        errorMessage = nil
        text = ""
        sourceCacheKey = nil
        batchEntries = []
        batchProgressCurrent = 0
        batchProgressTotal = 0
    }

    func clearCache() {
        cacheStore.removeAll()
    }

    /// Used by tests and visual QA.
    func waitForCurrentRecognition() async {
        await task?.value
    }

    #if DEBUG
    func seedBatchPreview(
        entries: [(title: String, imageURL: URL, text: String)]
    ) {
        task?.cancel()
        isPresenting = true
        isBatchMode = true
        batchEntries = entries.map { entry in
            BatchEntry(
                id: UUID(),
                cacheKey: UUID().uuidString,
                title: entry.title,
                imageURL: entry.imageURL,
                text: entry.text,
                phase: entry.text.isEmpty ? .empty : .success,
                errorMessage: nil
            )
        }
        batchProgressTotal = batchEntries.count
        batchProgressCurrent = batchEntries.count
    }

    func seedPreview(
        sourceTitle: String,
        imageURL: URL?,
        text: String
    ) {
        task?.cancel()
        isBatchMode = false
        batchEntries = []
        self.sourceTitle = sourceTitle
        self.sourceImageURL = imageURL
        self.text = text
        self.phase = text.isEmpty ? .empty : .success
        self.isPresenting = true
        self.errorMessage = nil
    }
    #endif

    private func cacheKey(for item: ClipboardItem) -> String {
        let identity = item.contentHash.isEmpty
            ? item.id.uuidString
            : item.contentHash
        return "\(identity)-\(recognitionLanguage.cacheSuffix)"
    }
}

enum VisionTextRecognizer {
    static func recognize(
        url: URL,
        language: OCRRecognitionLanguage = .automatic
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try recognizeSynchronously(url: url, language: language)
        }.value
    }

    private static func recognizeSynchronously(
        url: URL,
        language: OCRRecognitionLanguage
    ) throws -> String {
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

        if language == .automatic {
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }
        } else {
            request.automaticallyDetectsLanguage = false
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            let requested = language.visionLanguages.filter { candidate in
                supported.contains {
                    $0.caseInsensitiveCompare(candidate) == .orderedSame
                }
            }
            if !requested.isEmpty {
                request.recognitionLanguages = requested
            }
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
