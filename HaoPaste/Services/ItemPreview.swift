//
//  ItemPreview.swift
//  HaoPaste
//
//  Builds the content shown in the quick preview overlay.
//

import AppKit
import Foundation

struct PreviewText {
    let attributedString: NSAttributedString
    let characterCount: Int
    let isTruncated: Bool
}

enum ItemPreviewBuilder {
    /// Keep very large clipboard values responsive. Anything longer is shown
    /// as a truncated plain-text preview with a notice.
    static let maxPreviewCharacters = 120_000

    static func text(
        for item: ClipboardItem,
        richText: RichTextPayload?
    ) -> PreviewText {
        let fullCharacterCount = item.plainText.count

        if let richText,
           let formatted = formattedString(from: richText),
           formatted.length <= maxPreviewCharacters {
            return PreviewText(
                attributedString: formatted,
                characterCount: fullCharacterCount,
                isTruncated: false
            )
        }

        let isTruncated = fullCharacterCount > maxPreviewCharacters
        let visibleText = isTruncated
            ? String(item.plainText.prefix(maxPreviewCharacters)) + "\n\n…"
            : item.plainText

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = item.type == .code ? 2 : 4
        paragraphStyle.paragraphSpacing = item.type == .code ? 0 : 6

        let font = item.type == .code
            ? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            : NSFont.systemFont(ofSize: 13, weight: .regular)

        let attributedString = NSAttributedString(
            string: visibleText,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        return PreviewText(
            attributedString: attributedString,
            characterCount: fullCharacterCount,
            isTruncated: isTruncated
        )
    }

    /// Converts cached RTF / HTML back into displayable text. Web content often
    /// carries absolute black text colors and very large headings; normalizing
    /// those keeps the preview legible in both light and dark appearances.
    static func formattedString(from payload: RichTextPayload) -> NSAttributedString? {
        if let rtfData = payload.rtfData, !rtfData.isEmpty,
           let attributed = try? NSAttributedString(
               data: rtfData,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ),
           !attributed.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalized(attributed)
        }

        if let htmlData = payload.htmlData, !htmlData.isEmpty,
           let attributed = try? NSAttributedString(
               data: htmlData,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue
               ],
               documentAttributes: nil
           ),
           !attributed.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalized(attributed)
        }

        return nil
    }

    private static func normalized(_ attributed: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attributed)
        let range = NSRange(location: 0, length: result.length)

        result.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
        result.removeAttribute(.backgroundColor, range: range)

        result.enumerateAttribute(.font, in: range) { value, fontRange, _ in
            guard let font = value as? NSFont else { return }
            let clampedSize = min(max(font.pointSize, 10), 20)
            guard clampedSize != font.pointSize else { return }

            let descriptor = font.fontDescriptor
            let clamped = NSFont(descriptor: descriptor, size: clampedSize)
                ?? NSFont.systemFont(ofSize: clampedSize)
            result.addAttribute(.font, value: clamped, range: fontRange)
        }

        return result
    }
}
