//
//  OCRRecognitionLanguage.swift
//  HaoPaste
//

import Foundation

enum OCRRecognitionLanguage: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case simplifiedChinese
    case traditionalChinese
    case english
    case japanese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动检测"
        case .simplifiedChinese: return "中文（简体）"
        case .traditionalChinese: return "中文（繁体）"
        case .english: return "英语"
        case .japanese: return "日语"
        }
    }

    var visionLanguages: [String] {
        switch self {
        case .automatic: return []
        case .simplifiedChinese: return ["zh-Hans", "en-US"]
        case .traditionalChinese: return ["zh-Hant", "en-US"]
        case .english: return ["en-US"]
        case .japanese: return ["ja-JP", "en-US"]
        }
    }

    var cacheSuffix: String {
        rawValue
    }
}
