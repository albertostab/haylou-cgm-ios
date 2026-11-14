import Foundation
@main struct HistoryWindowTest {
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1800000000)
        var points = (0..<360).map { i in GlucosePoint(date: now.addingTimeInterval(Double(-i*60)), value: 100) }
        points[13].value = 45; points[14].value = 270
        points.append(GlucosePoint(date: now.addingTimeInterval(-22000), value: 500))
        let output = HistoryWindow.summarize(points, now: now)
        precondition(output.count <= 72)
        precondition(output.contains { $0.value == 45 })
        precondition(output.contains { $0.value == 270 })
        precondition(!output.contains { $0.value == 500 })
        let payload = try JSONEncoder().encode(output)
        precondition(payload.count < 3500)
        let day = (0..<1440).map { GlucosePoint(date: now.addingTimeInterval(Double(-$0*60)), value: $0 % 2 == 0 ? 55 : 250) }
        let packed = HistoryWindow.pack(day, now: now)
        precondition(packed.count <= 480)
        let encoded = try JSONEncoder().encode(packed)
        precondition(encoded.count < 3500)
        precondition(HistoryWindow.unpack(packed, anchor: now).count == packed.count / 2)
        print("PASS: six-hour envelope, extremes retained, ActivityKit payload bounded")
    }
}
