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
            guard points.count > 1 else { return }
            let end = Date()
            let start = end.addingTimeInterval(-21600)
            let duration = 21600.0
            let low = Double(min(60, points.map(\.value).min() ?? 60)) - 10
            let high = Double(max(190, points.map(\.value).max() ?? 190)) + 10
            func position(_ point: GlucosePoint) -> CGPoint {
                CGPoint(x: point.date.timeIntervalSince(start) / duration * size.width,
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
                var cuts = [0.0, 1.0]
                if a.value != b.value {
                    for threshold in [70.0, 180.0] {
                        let t = (threshold - Double(a.value)) / Double(b.value - a.value)
                        if t > 0 && t < 1 { cuts.append(t) }
                    }
                }
                cuts.sort()
                let pa = position(a), pb = position(b)
                for k in 1..<cuts.count {
                    let t0 = cuts[k-1], t1 = cuts[k]
                    let middle = Double(a.value) + Double(b.value-a.value) * (t0+t1)/2
                    var segment = Path()
                    segment.move(to: CGPoint(x: pa.x+(pb.x-pa.x)*t0, y: pa.y+(pb.y-pa.y)*t0))
                    segment.addLine(to: CGPoint(x: pa.x+(pb.x-pa.x)*t1, y: pa.y+(pb.y-pa.y)*t1))
                    context.stroke(segment, with: .color(middle < 70 || middle > 180 ? .red : .white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }.accessibilityLabel("Andamento glicemia; rosso fuori 70–180")
    }
}
struct BridgeLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BridgeActivityAttributes.self) { context in
            HStack(spacing: 12) {
                GlucoseSparkline(points: context.state.history ?? []).frame(height: 44)
                    .opacity(context.isStale ? 0.4 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(value(context.state, stale: context.isStale))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit().foregroundStyle(color(context.state))
                    if context.isStale { Text("Dato vecchio").font(.caption2).foregroundStyle(.orange) }
                }
            }.padding(.horizontal, 16).padding(.vertical, 10).privacySensitive()
                .activityBackgroundTint(.black).activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(value(context.state, stale: context.isStale)).font(.title2.bold()).foregroundStyle(color(context.state)).frame(maxWidth: .infinity, alignment: .center).privacySensitive()
                }
            } compactLeading: {
                Text(value(context.state, stale: context.isStale))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(color(context.state))
                    .lineLimit(1).minimumScaleFactor(0.8).fixedSize(horizontal: true, vertical: false).privacySensitive()
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
