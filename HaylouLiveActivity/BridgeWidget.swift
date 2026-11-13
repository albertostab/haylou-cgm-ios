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
                Text(context.isStale ? "Sessione da verificare: dati non aggiornati" : context.state.status)
                if let date = context.state.readingDate {
                    HStack { Text("Età lettura:"); Text(date, style: .relative) }
                }
                Text("Display RT2 non confermato · nessuna frequenza garantita").font(.caption)
            }.padding().activityBackgroundTint(.black).activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { Text("Haylou CGM · " + context.state.status) }
                DynamicIslandExpandedRegion(.bottom) { Text("Display non confermato").font(.caption) }
            } compactLeading: { Text("RT2") } compactTrailing: {
                Image(systemName: "antenna.radiowaves.left.and.right")
            } minimal: { Text("RT2") }
        }
    }
}
