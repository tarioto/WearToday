import CoreLocation
import Foundation

/// Decides whether the widgets' plan is out of date and, if so, fetches and publishes today's plan.
/// Used by the background app refresh task; everything it touches is injected so tests can drive it.
@MainActor
struct BackgroundPlanRefresher {
    enum Outcome: Equatable {
        /// The saved plan was generated today (device time zone); nothing fetched.
        case alreadyCurrent
        /// A new plan was fetched and published.
        case refreshed
        /// Current Location is selected but there's no known fix; nothing fetched.
        case skippedNoCoordinate
        /// Weather or the on-device recommendation failed; the saved plan was left as is.
        case failed
    }

    let fetcher: DayPlanFetching
    /// Defines "today"; production passes the device's current calendar and time zone.
    let calendar: Calendar
    let now: () -> Date
    let loadSnapshot: () -> PlanSnapshot?
    let publish: (PlanSnapshot) -> Void
    let selection: () -> LocationSelection
    let lastKnownGPSCoordinate: () -> CLLocationCoordinate2D?
    let provider: () -> WeatherProvider

    /// How long to wait before trying again while the saved plan is still from an earlier day.
    static let staleRetryInterval: TimeInterval = 60 * 60
    /// Run a little after midnight so "today" has clearly rolled over.
    static let minutesAfterMidnight = 5

    func refreshIfStale() async -> Outcome {
        guard !hasCurrentSnapshot else { return .alreadyCurrent }

        let coordinate: CLLocationCoordinate2D
        switch selection() {
        case .custom(_, let latitude, let longitude):
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        case .currentLocation:
            guard let lastFix = lastKnownGPSCoordinate() else { return .skippedNoCoordinate }
            coordinate = lastFix
        }

        let provider = provider()
        guard let (weather, _) = try? await fetcher.fetchWeather(for: coordinate, from: provider),
              let recommendation = try? await fetcher.recommendation(for: weather) else { return .failed }
        publish(PlanSnapshot(weather: weather, recommendation: recommendation, generatedAt: now(), provider: provider))
        return .refreshed
    }

    /// When the next background refresh should run: just after the next local midnight, or
    /// sooner if the saved plan is still from an earlier day (e.g. this run failed).
    func nextRequestDate() -> Date {
        let now = now()
        guard hasCurrentSnapshot else { return now.addingTimeInterval(Self.staleRetryInterval) }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        return calendar.date(byAdding: .minute, value: Self.minutesAfterMidnight, to: calendar.startOfDay(for: tomorrow))!
    }

    private var hasCurrentSnapshot: Bool {
        guard let snapshot = loadSnapshot() else { return false }
        return calendar.isDate(snapshot.generatedAt, inSameDayAs: now())
    }
}
