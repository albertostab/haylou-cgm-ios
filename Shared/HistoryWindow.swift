import Foundation
// Read all six-hour samples; send min/max envelopes to ActivityKit within its 4 KB budget.
enum HistoryWindow {
    static func summarize(_ points: [GlucosePoint], now: Date) -> [GlucosePoint] {
        let start = now.addingTimeInterval(-21600)
        let valid = points.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
        var result: [GlucosePoint] = []
        for bucket in 0..<36 {
            let lower = start.addingTimeInterval(Double(bucket) * 600)
            let upper = lower.addingTimeInterval(600)
            let values = valid.filter { $0.date >= lower && ($0.date < upper || bucket == 35) }
            guard let min = values.min(by: { $0.value < $1.value }),
                  let max = values.max(by: { $0.value < $1.value }) else { continue }
            result.append(min)
            if max.date != min.date { result.append(max) }
        }
        return result.sorted { $0.date < $1.date }
    }
}
