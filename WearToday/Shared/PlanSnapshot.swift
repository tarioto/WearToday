import Foundation

struct PlanSnapshot: Codable, Sendable {
    let weather: DailyWeather
    let recommendation: OutfitRecommendation
    let generatedAt: Date
}

extension PlanSnapshot {
    static let placeholder = PlanSnapshot(
        weather: .placeholder,
        recommendation: .placeholder,
        generatedAt: .now
    )
}

enum SharedStore {
    static let appGroupID = "group.com.timarioto.WearToday"
    private static let snapshotKey = "latestPlanSnapshot"

    static func save(_ snapshot: PlanSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> PlanSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(PlanSnapshot.self, from: data)
    }
}
