import Foundation

/// Selects work that fits an actual execution opportunity; does not create runtime.
enum RefreshPolicy {
    static func includeHistory(foreground: Bool, lastHistory: Date?, now: Date) -> Bool {
        guard foreground else { return false }
        guard let lastHistory = lastHistory else { return true }
        return now.timeIntervalSince(lastHistory) >= 300
    }
    static func mergeHistory(_ cached: [GlucosePoint], incoming: [GlucosePoint], now: Date) -> [GlucosePoint] {
        let cutoff = now.addingTimeInterval(-86400)
        var values: [Int64: GlucosePoint] = [:]
        for point in cached + incoming where point.date >= cutoff && point.date <= now {
            values[Int64((point.date.timeIntervalSince1970 * 1000).rounded())] = point
        }
        return values.values.sorted { $0.date < $1.date }
    }
    static func findPhoneCheckDue(lastCheck: Date?, now: Date) -> Bool {
        now.timeIntervalSince(lastCheck ?? .distantPast) >= 5
    }
    static func bleCheckDue(lastSuccess: Date?, lastAttempt: Date?, now: Date) -> Bool {
        now.timeIntervalSince(lastSuccess ?? .distantPast) >= 55 &&
        now.timeIntervalSince(lastAttempt ?? .distantPast) >= 15
    }
}
