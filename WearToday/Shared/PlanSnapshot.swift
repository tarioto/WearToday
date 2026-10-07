import Foundation

struct PlanSnapshot: Codable, Sendable {
    let weather: DailyWeather
    let recommendation: OutfitRecommendation
    let generatedAt: Date
    /// Optional so snapshots saved before providers existed still decode.
    var provider: WeatherProvider?
}

extension PlanSnapshot {
    static let placeholder = PlanSnapshot(
        weather: .placeholder,
        recommendation: .placeholder,
        generatedAt: .now,
        provider: .openMeteo
    )
}

enum SharedStore {
    static let appGroupID = "group.com.timarioto.WearToday"
    private static let snapshotKey = "latestPlanSnapshot"
    private static let temperatureUnitKey = "temperatureUnit"

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

    static func saveTemperatureUnit(_ unit: TemperatureUnit) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(unit.rawValue, forKey: temperatureUnitKey)
    }

    static func loadTemperatureUnit() -> TemperatureUnit {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let raw = defaults.string(forKey: temperatureUnitKey),
              let unit = TemperatureUnit(rawValue: raw) else {
            return .system
        }
        return unit
    }
}
