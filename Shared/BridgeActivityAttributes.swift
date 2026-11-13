import ActivityKit

import Foundation



struct BridgeActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {

        var glucose: Int?
        var readingDate: Date?

        var writeDate: Date?

        var status: String

    }

    var sessionName: String

}

