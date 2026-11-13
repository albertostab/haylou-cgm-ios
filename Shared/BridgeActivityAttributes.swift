import ActivityKit
import Foundation

struct BridgeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var readingDate: Date?
        var writeDate: Date?
        var status: String
    }
    var sessionName: String
}
