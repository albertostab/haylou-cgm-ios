import ActivityKit
import Foundation
struct GlucosePoint: Codable, Hashable {
    var date: Date
    var value: Int
}
struct BridgeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var history: [GlucosePoint]?
        var direction: String?
        var glucose: Int?
        var readingDate: Date?
        var writeDate: Date?
        var status: String
    }
    var sessionName: String
}
