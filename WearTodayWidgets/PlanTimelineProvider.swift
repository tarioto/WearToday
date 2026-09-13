import WidgetKit

struct PlanEntry: TimelineEntry {
    let date: Date
    let snapshot: PlanSnapshot?
}

struct PlanTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlanEntry {
        PlanEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlanEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : SharedStore.load()
        completion(PlanEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlanEntry>) -> Void) {
        let entry = PlanEntry(date: .now, snapshot: SharedStore.load())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
