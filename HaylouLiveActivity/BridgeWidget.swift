import ActivityKit
import WidgetKit
import SwiftUI
@main struct BridgeWidgets: WidgetBundle {
    var body: some Widget { BridgeLiveWidget() }
}
struct BridgeLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BridgeActivityAttributes.self) { context in
            VStack(alignment: .leading) {
                Text("Haylou CGM · sessione sperimentale").font(.headline)
                Text(context.state.glucose.map { "\($0) \(Trend.symbol(context.state.direction ?? "")) mg/dL" } ?? "In attesa di lettura").font(.largeTitle.bold()).privacySensitive()
                Text(context.isStale ? "Sessione da verificare: dati non aggiornati" : context.state.status)
                if let date = context.state.readingDate {
                    HStack { Text("Età lettura:"); Text(date, style: .relative) }
                }
                Text("Display RT2 non confermato · nessuna frequenza garantita").font(.caption)
            }.padding().activityBackgroundTint(.black).activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text(context.state.glucose.map { "\($0) \(Trend.symbol(context.state.direction ?? "")) mg/dL" } ?? "--").font(.title.bold()).privacySensitive()
                        Text(context.isStale ? "DATO OBSOLETO" : context.state.status).font(.caption)
                        if let date = context.state.readingDate { Text(date, style: .relative) }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) { Text("Display non confermato").font(.caption) }
            } compactLeading: {
                EmptyView()
            } compactTrailing: {
                Text(compactValue(context.state, stale: context.isStale))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .privacySensitive()
                    .accessibilityLabel("Glicemia " + compactValue(context.state, stale: context.isStale))
            } minimal: {
                Text(compactValue(context.state, stale: context.isStale))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .privacySensitive()
            }
        }
    }
    private func compactValue(_ state: BridgeActivityAttributes.ContentState, stale: Bool) -> String {
        let value = state.glucose.map(String.init) ?? "--"
        // Never present an old trend as current.
        return value + " " + (stale ? "!" : Trend.symbol(state.direction ?? ""))
    }
}
