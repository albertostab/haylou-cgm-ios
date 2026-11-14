import Foundation
@main struct SyncPolicyTest {
    static func main() {
        precondition(Trend.symbol("Flat") == "→")
        precondition(Trend.symbol("DoubleDown") == "↓↓")
        precondition(Trend.symbol("NOT COMPUTABLE") == "?")
        precondition(Trend.climate("Flat") == 1)
        precondition(Trend.climate("DoubleDown") != Trend.climate("DoubleUp"))
        let now = Date(timeIntervalSince1970: 1800000000)
        let ms: Int64 = 1800000000000
        precondition(SyncPolicy.shouldSend(timestamp: ms, previous: ms - 1, now: now))
        precondition(!SyncPolicy.shouldSend(timestamp: ms, previous: ms, now: now))
        precondition(!SyncPolicy.shouldSend(timestamp: ms - 721000, previous: 0, now: now))
        precondition(!SyncPolicy.shouldSend(timestamp: ms + 121000, previous: 0, now: now))
        precondition(SyncPolicy.shouldSend(timestamp: ms - 720000, previous: 0, now: now))
        precondition(SyncPolicy.retryDelay(0) == 2)
        precondition(SyncPolicy.retryDelay(3) == 16)
        precondition(SyncPolicy.retryDelay(100) == 300)
        print("PASS: stale/future protection, ordering, duplicate suppression, bounded backoff")
    }
}
