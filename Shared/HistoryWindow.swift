import Foundation
// Read all six-hour samples; send min/max envelopes to ActivityKit within its 4 KB budget.
enum HistoryWindow {
    static func summarize(_ points: [GlucosePoint], now: Date, hours: Int = 6, buckets: Int = 36) -> [GlucosePoint] {
        let start = now.addingTimeInterval(-Double(hours * 3600))
        let valid = points.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
        var result: [GlucosePoint] = []
        for bucket in 0..<buckets {
            let lower = start.addingTimeInterval(Double(bucket) * Double(hours * 3600) / Double(buckets))
            let upper = lower.addingTimeInterval(Double(hours * 3600) / Double(buckets))
            let values = valid.filter { $0.date >= lower && ($0.date < upper || bucket == buckets - 1) }
            guard let min = values.min(by: { $0.value < $1.value }),
                  let max = values.max(by: { $0.value < $1.value }) else { continue }
            result.append(min)
            if max.date != min.date { result.append(max) }
        }
        return result.sorted { $0.date < $1.date }
    }
    static func pack(_ points: [GlucosePoint], now: Date) -> [Int] {
        summarize(points, now: now, hours: 24, buckets: 120).flatMap {
            [Int($0.date.timeIntervalSince(now)), $0.value]
        }
    }
    static func unpack(_ values: [Int], anchor: Date) -> [GlucosePoint] {
        stride(from: 0, to: values.count - values.count % 2, by: 2).map {
            GlucosePoint(date: anchor.addingTimeInterval(Double(values[$0])), value: values[$0+1])
        }
    }
}
