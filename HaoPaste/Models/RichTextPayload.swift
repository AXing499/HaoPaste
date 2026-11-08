//
//  RichTextPayload.swift
//  HaoPaste
//
//  Raw rich-text representations captured alongside plain text.
//

import Foundation

struct RichTextPayload: Codable, Hashable, Sendable {
    var rtfData: Data?
    var htmlData: Data?

    var isEmpty: Bool {
        (rtfData?.isEmpty ?? true) && (htmlData?.isEmpty ?? true)
    }
}
