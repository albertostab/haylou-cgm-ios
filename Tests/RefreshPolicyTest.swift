import Foundation
@main struct RefreshPolicyTest {
    static func main() {
        let now = Date(timeIntervalSince1970: 1800000000)
        precondition(!RefreshPolicy.includeHistory(foreground: false, lastHistory: nil, now: now))
        precondition(RefreshPolicy.includeHistory(foreground: true, lastHistory: nil, now: now))
        precondition(!RefreshPolicy.includeHistory(foreground: true, lastHistory: now.addingTimeInterval(-299), now: now))
        precondition(RefreshPolicy.includeHistory(foreground: true, lastHistory: now.addingTimeInterval(-300), now: now))
        let cached = [GlucosePoint(date: now.addingTimeInterval(-90000), value: 50), GlucosePoint(date: now.addingTimeInterval(-600), value: 120)]
        let incoming = [GlucosePoint(date: now.addingTimeInterval(-600), value: 121), GlucosePoint(date: now, value: 150), GlucosePoint(date: now.addingTimeInterval(100), value: 200)]
        let merged = RefreshPolicy.mergeHistory(cached, incoming: incoming, now: now)
        precondition(merged.count == 2 && merged[0].value == 121 && merged[1].value == 150)
        precondition(RefreshPolicy.bleCheckDue(lastSuccess: now.addingTimeInterval(-60), lastAttempt: now.addingTimeInterval(-20), now: now))
        precondition(!RefreshPolicy.bleCheckDue(lastSuccess: now.addingTimeInterval(-10), lastAttempt: now.addingTimeInterval(-20), now: now))
        precondition(!RefreshPolicy.bleCheckDue(lastSuccess: nil, lastAttempt: now.addingTimeInterval(-5), now: now))
        print("PASS: lightweight background policy; history merge/dedup/retention; BLE event checks and failure retry rate limits")
    }
}
