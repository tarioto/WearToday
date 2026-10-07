import SwiftUI
import WidgetKit

struct CombinedWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PlanEntry

    private var itemLimit: Int {
        switch family {
        case .systemMedium: return 3
        case .systemLarge: return 6
        default: return 8
        }
    }

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 10) {
                header(for: snapshot)

                if family != .systemMedium {
                    Text(snapshot.recommendation.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(family == .systemLarge ? 3 : 4)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(snapshot.recommendation.items.prefix(itemLimit)), id: \.name) { item in
                        HStack(spacing: 8) {
                            Text(item.emoji)
                            Text(item.name)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }

                if let provider = snapshot.provider {
                    Spacer(minLength: 0)
                    Link(destination: provider.attributionURL) {
                        WeatherAttributionLabel(provider: provider)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            EmptyPlanView()
        }
    }

    private func header(for snapshot: PlanSnapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.weather.conditionDescription)
                    .font(.headline)
                let unit = SharedStore.loadTemperatureUnit()
                Text("H:\(unit.displayString(fromFahrenheit: snapshot.weather.highTemperatureF)) L:\(unit.displayString(fromFahrenheit: snapshot.weather.lowTemperatureF))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: WMOWeatherCode.symbolName(for: snapshot.weather.conditionCode))
                .font(.title2)
                .symbolRenderingMode(.multicolor)
        }
    }
}

struct CombinedWidget: Widget {
    let kind = "CombinedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlanTimelineProvider()) { entry in
            CombinedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Full Plan")
        .description("Weather, summary, and everything to wear and bring today.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

#Preview(as: .systemLarge) {
    CombinedWidget()
} timeline: {
    PlanEntry(date: .now, snapshot: .placeholder)
}
