//
//  ClipboardShelfFilter.swift
//  HaoPaste
//

import Foundation

enum ClipboardShelfFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L("全部")
        case .text: return L("文本")
        case .image: return L("图片")
        }
    }

    var emptyTitle: String {
        switch self {
        case .all: return L("暂无记录")
        case .text: return L("暂无文本记录")
        case .image: return L("暂无图片记录")
        }
    }

    var symbolName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.alignleft"
        case .image: return "photo"
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all:
            return true
        case .text:
            return item.type == .text
                || item.type == .code
                || item.type == .url
                || item.type == .colorHex
        case .image:
            return item.type == .image
        }
    }
}
