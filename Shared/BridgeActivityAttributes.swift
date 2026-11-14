import ActivityKit
import Foundation
struct BridgeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var packedHistory: [Int]?
        var historyAnchor: Date?
        var selectedHours: Int?
        var direction: String?
        var glucose: Int?
        var readingDate: Date?
        var writeDate: Date?
        var status: String
    }
    var sessionName: String
}
