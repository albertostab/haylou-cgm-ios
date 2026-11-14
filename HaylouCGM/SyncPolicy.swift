import Foundation
enum SyncPolicy {
    static func retryDelay(_ attempt: Int) -> Double {
        min(300, 2 * pow(2, Double(min(max(0, attempt), 8))))
    }
    static func shouldSend(timestamp: Int64, previous: Int64, now: Date) -> Bool {
        let age = now.timeIntervalSince1970 - Double(timestamp) / 1000
        return timestamp > previous && age >= -120 && age <= 720
    }
}
