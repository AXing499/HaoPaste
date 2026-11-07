//
//  ImageProcessor.swift
//  HaoPaste
//
//  Image decoding, PNG normalisation and thumbnail generation.
//

import AppKit
import ImageIO
import UniformTypeIdentifiers

enum ImageProcessor {
    struct PreparedImage {
        let fullData: Data
        let thumbnailData: Data
        let dimensions: ImageDimensions
    }

    /// Decodes image data, normalises the full-size copy to PNG and creates a
    /// compact thumbnail used by the history list.
    static func prepare(from data: Data, maxThumbnailPixelSize: Int = 560) -> PreparedImage? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        let dimensions = ImageDimensions(width: cgImage.width, height: cgImage.height)

        let fullData: Data
        if (CGImageSourceGetType(source) as String?) == UTType.png.identifier {
            fullData = data
        } else {
            let representation = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = representation.representation(using: .png, properties: [:]) else {
                return nil
            }
            fullData = pngData
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxThumbnailPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard
            let thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
        else {
            return nil
        }

        let thumbnailRepresentation = NSBitmapImageRep(cgImage: thumbnailCGImage)
        guard let thumbnailData = thumbnailRepresentation.representation(using: .png, properties: [:]) else {
            return nil
        }

        return PreparedImage(
            fullData: fullData,
            thumbnailData: thumbnailData,
            dimensions: dimensions
        )
    }

    static func dimensions(of data: Data) -> ImageDimensions? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0,
            height > 0
        else {
            return nil
        }

        return ImageDimensions(width: width, height: height)
    }
}
