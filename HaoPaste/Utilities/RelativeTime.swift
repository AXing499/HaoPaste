//
//  RelativeTime.swift
//  HaoPaste
//
//  Compact relative timestamps for the history list.
//

import Foundation

enum RelativeTime {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    static func string(
        from date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let interval = now.timeIntervalSince(date)

        if interval < 0 || interval < 60 {
            return L("刚刚")
        }

        if interval < 3_600 {
            return L("%d 分钟前", max(1, Int(interval / 60)))
        }

        if calendar.isDateInToday(date) {
            return timeFormatter.string(from: date)
        }

        if calendar.isDateInYesterday(date) {
            return L("昨天 %@", timeFormatter.string(from: date))
        }

        let startOfDate = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)
        let dayDistance = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day ?? 0

        if dayDistance < 7 {
            return "\(weekdayFormatter.string(from: date)) \(timeFormatter.string(from: date))"
        }

        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return shortDateFormatter.string(from: date)
        }

        return fullDateFormatter.string(from: date)
    }
}
