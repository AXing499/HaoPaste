//
//  ClipboardShelfEdge.swift
//  HaoPaste
//
//  Which screen edge hosts the clipboard shelf.
//

import Foundation

enum ClipboardShelfEdge: String, CaseIterable, Identifiable {
    case top
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top: return L("顶部")
        case .left: return L("左侧")
        case .right: return L("右侧")
        }
    }

    var symbolName: String {
        switch self {
        case .top: return "menubar.rectangle"
        case .left: return "sidebar.left"
        case .right: return "sidebar.right"
        }
    }

    var isSide: Bool {
        self != .top
    }
}
