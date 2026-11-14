import ActivityKit
import Foundation
final class LiveSession {
    static let shared = LiveSession()
    private var activity: Activity<BridgeActivityAttributes>?
    var isActive: Bool { Activity<BridgeActivityAttributes>.activities.contains { $0.activityState == .active || $0.activityState == .stale } }
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
    func update(history: [GlucosePoint], direction: String, glucose: Int?, reading: Date?, write: Date?, status: String, log: @escaping (String) -> Void = { _ in }, completion: @escaping () -> Void = {}) {
        guard let activity = Activity<BridgeActivityAttributes>.activities.first(where: { $0.activityState == .active || $0.activityState == .stale }) else { log("Live Activity update skipped: no updatable activity"); completion(); return }
        let now = Date()
        let state = BridgeActivityAttributes.ContentState(packedHistory: HistoryWindow.pack(history, now: now), historyAnchor: now, selectedHours: activity.content.state.selectedHours ?? 6, direction: direction, glucose: glucose, readingDate: reading, writeDate: write, status: status)
        guard let payload = try? JSONEncoder().encode(state), payload.count < 3800 else {
            log("Live Activity update skipped: payload exceeds safe budget"); completion(); return
        }
        log("Live Activity update started; bytes=\(payload.count)")
        Task { @MainActor in
            await activity.update(ActivityContent(state: state,
                staleDate: reading?.addingTimeInterval(180) ?? Date().addingTimeInterval(60)))
            log("Live Activity update call completed; state=\(activity.activityState); visual rendering not confirmed")
            completion()
        }
    }
    func stop(log: (String) -> Void) {
        let activities = Activity<BridgeActivityAttributes>.activities
        activity = nil
        Task { for item in activities { await item.end(nil, dismissalPolicy: .immediate) } }
        log("Live Activity end requested")
    }
}
