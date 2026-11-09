//
//  TrashedClipboardItem.swift
//  HaoPaste
//
//  A clipboard entry kept in Recently Deleted until its retention expires.
//

import Foundation

struct TrashedClipboardItem: Identifiable, Codable, Hashable, Sendable {
    let item: ClipboardItem
    let deletedAt: Date

    var id: UUID { item.id }
}
