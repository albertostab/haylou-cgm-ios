import ActivityKit
import Foundation
final class LiveSession {
    static let shared = LiveSession()
    private var activity: Activity<BridgeActivityAttributes>?
    var isActive: Bool { Activity<BridgeActivityAttributes>.activities.contains { $0.activityState == .active } }
    func start(log: (String) -> Void) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log("Live Activity unavailable/disabled in iOS settings"); return
        }
        if let current = Activity<BridgeActivityAttributes>.activities.first {
            activity = current; log("Live Activity recovered; no runtime guarantee"); return
        }
        do {
            let state = BridgeActivityAttributes.ContentState(status: "Sessione attiva; in attesa di dati")
            activity = try Activity.request(attributes: BridgeActivityAttributes(sessionName: "RT2"),
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(720)), pushType: nil)
            log("Live Activity started in foreground; background benefit unverified")
        } catch { log("Live Activity start failed code=\((error as NSError).code)") }
    }
    func update(glucose: Int?, reading: Date?, write: Date?, status: String) {
        guard let activity = activity ?? Activity<BridgeActivityAttributes>.activities.first else { return }
        let state = BridgeActivityAttributes.ContentState(glucose: glucose, readingDate: reading, writeDate: write, status: status)
        Task { await activity.update(ActivityContent(state: state,
            staleDate: reading?.addingTimeInterval(720) ?? Date().addingTimeInterval(60))) }
    }
    func stop(log: (String) -> Void) {
        let activities = Activity<BridgeActivityAttributes>.activities
        activity = nil
        Task { for item in activities { await item.end(nil, dismissalPolicy: .immediate) } }
        log("Live Activity end requested")
    }
}
