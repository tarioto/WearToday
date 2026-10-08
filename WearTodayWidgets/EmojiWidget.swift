import SwiftUI
import WidgetKit

struct EmojiWidgetEntryView: View {
    var entry: PlanEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(snapshot.recommendation.displayedItems(limit: 4)) { row in
                    Text(row.item.emoji)
                        .font(.system(size: 34))
                }
            }
            .padding(4)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            EmptyPlanView()
        }
    }
}

struct EmojiWidget: Widget {
    let kind = "EmojiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlanTimelineProvider()) { entry in
            EmojiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Emojis")
        .description("A quick emoji glance at what to wear and bring today.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    EmojiWidget()
} timeline: {
    PlanEntry(date: .now, snapshot: .placeholder)
}
