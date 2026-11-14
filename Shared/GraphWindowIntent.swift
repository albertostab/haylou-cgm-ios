import ActivityKit
import AppIntents
struct GraphWindowIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Finestra grafico"
    static var openAppWhenRun: Bool = false
    @Parameter(title: "Ore") var hours: Int
    init() {}
    init(hours: Int) { self.hours = hours }
    func perform() async throws -> some IntentResult {
        guard [3,6,24].contains(hours) else { return .result() }
        for activity in Activity<BridgeActivityAttributes>.activities {
            var state = activity.content.state
            state.selectedHours = hours
            await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
        }
        return .result()
    }
}
