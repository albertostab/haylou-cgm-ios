import ActivityKit
import WidgetKit
import SwiftUI
@main struct BridgeWidgets: WidgetBundle {
    var body: some Widget { BridgeLiveWidget() }
}
struct GlucoseSparkline: View {
    let points: [GlucosePoint]
    var body: some View {
        Canvas { context, size in
            guard points.count > 1, let first = points.first, let last = points.last else { return }
            let duration = max(1, last.date.timeIntervalSince(first.date))
            let low = Double(min(60, points.map(\.value).min() ?? 60)) - 10
            let high = Double(max(190, points.map(\.value).max() ?? 190)) + 10
            func position(_ point: GlucosePoint) -> CGPoint {
                CGPoint(x: point.date.timeIntervalSince(first.date) / duration * size.width,
                        y: (high - Double(point.value)) / (high - low) * size.height)
            }
            for threshold in [70.0, 180.0] {
                let y = (high - threshold) / (high - low) * size.height
                var path = Path(); path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.gray.opacity(0.4)), style: StrokeStyle(lineWidth: 0.5, dash: [3,3]))
            }
            for i in 1..<points.count {
                let a = points[i-1], b = points[i]
                guard b.date.timeIntervalSince(a.date) <= 900 else { continue }
                var path = Path(); path.move(to: position(a)); path.addLine(to: position(b))
                let outside = a.value < 70 || a.value > 180 || b.value < 70 || b.value > 180
                context.stroke(path, with: .color(outside ? .red : .white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }.accessibilityLabel("Andamento glicemia; rosso fuori 70–180")
    }
}
struct BridgeLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BridgeActivityAttributes.self) { context in
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value(context.state, stale: context.isStale))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit().foregroundStyle(color(context.state))
                    if context.isStale { Text("Dato vecchio").font(.caption2).foregroundStyle(.orange) }
                }
                GlucoseSparkline(points: context.state.history ?? []).frame(height: 44)
                    .opacity(context.isStale ? 0.4 : 1)
            }.padding(.horizontal, 16).padding(.vertical, 10).privacySensitive()
                .activityBackgroundTint(.black).activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 12) {
                        Text(value(context.state, stale: context.isStale)).font(.title2.bold()).foregroundStyle(color(context.state))
                        GlucoseSparkline(points: context.state.history ?? []).frame(height: 34)
                    }.privacySensitive()
                }
            } compactLeading: {
                Text(value(context.state, stale: context.isStale))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(color(context.state))
                    .lineLimit(1).minimumScaleFactor(0.8).privacySensitive()
            } compactTrailing: { EmptyView() } minimal: {
                Text(value(context.state, stale: context.isStale))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(color(context.state))
                    .lineLimit(1).minimumScaleFactor(0.7).privacySensitive()
            }
        }
    }
    private func color(_ state: BridgeActivityAttributes.ContentState) -> Color {
        guard let value = state.glucose else { return .white }
        return value < 70 || value > 180 ? .red : .white
    }
    private func value(_ state: BridgeActivityAttributes.ContentState, stale: Bool) -> String {
        (state.glucose.map(String.init) ?? "--") + " " + (stale ? "!" : Trend.symbol(state.direction ?? ""))
    }
}
