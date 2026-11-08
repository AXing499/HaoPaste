//
//  ItemDragProvider.swift
//  HaoPaste
//
//  Builds pasteboard item providers so history entries can be dragged into
//  other applications.
//

import AppKit
import UniformTypeIdentifiers

@MainActor
enum ItemDragProvider {
    static func make(
        for item: ClipboardItem,
        imageURL: URL?,
        richText: RichTextPayload?
    ) -> NSItemProvider {
        switch item.type {
        case .image:
            guard let imageURL else {
                return textProvider(item.plainText)
            }
            return imageProvider(url: imageURL)

        case .file:
            if let url = item.availableFileURLs.first,
               let provider = NSItemProvider(contentsOf: url) {
                return provider
            }
            return textProvider(item.plainText)

        case .text, .code, .url, .colorHex:
            return textProvider(item.content, richText: richText)
        }
    }

    static func textProvider(
        _ text: String,
        richText: RichTextPayload? = nil
    ) -> NSItemProvider {
        let provider = NSItemProvider(object: text as NSString)

        if let rtfData = richText?.rtfData, !rtfData.isEmpty {
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.rtf.identifier,
                visibility: .all
            ) { completion in
                completion(rtfData, nil)
                return nil
            }
        }

        if let htmlData = richText?.htmlData, !htmlData.isEmpty {
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.html.identifier,
                visibility: .all
            ) { completion in
                completion(htmlData, nil)
                return nil
            }
        }

        return provider
    }

    static func imageProvider(url: URL) -> NSItemProvider {
        let provider = NSItemProvider(contentsOf: url) ?? NSItemProvider()

        // File URLs work in Finder, while a data representation lets chat and
        // mail apps accept the drag as an inline image.
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.png.identifier,
            visibility: .all
        ) { completion in
            do {
                completion(try Data(contentsOf: url), nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }

        return provider
    }
}
