import CoreLocation
import Foundation
import Testing
@testable import WearToday

@MainActor
struct BackgroundPlanRefreshTests {
    @Test func snapshotFromTodayIsLeftAloneWithoutFetching() async {
        let harness = Harness(now: date("2026-10-08T09:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-08T00:30:00-07:00"))

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .alreadyCurrent)
        #expect(await harness.fetcher.weatherRequests.isEmpty)
        #expect(harness.published.isEmpty)
    }

    @Test func snapshotFromYesterdayIsReplacedWithPlanForCustomCity() async {
        let now = date("2026-10-08T06:00:00-07:00")
        let harness = Harness(now: now)
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        harness.lastKnownGPSCoordinate = CLLocationCoordinate2D(latitude: 1, longitude: 2)
        harness.provider = .openMeteo

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .refreshed)
        #expect(await harness.fetcher.weatherRequests == [WeatherRequest(latitude: 47.6, longitude: -122.3, provider: .openMeteo)])
        #expect(harness.published.map(\.generatedAt) == [now])
        #expect(harness.published.map(\.provider) == [.openMeteo])
    }

    @Test func missingSnapshotIsFilledUsingLastKnownGPSFixForCurrentLocation() async {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = nil
        harness.selection = .currentLocation
        harness.lastKnownGPSCoordinate = CLLocationCoordinate2D(latitude: 37.3, longitude: -122.0)
        harness.provider = .apple

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .refreshed)
        #expect(await harness.fetcher.weatherRequests == [WeatherRequest(latitude: 37.3, longitude: -122.0, provider: .apple)])
        #expect(harness.published.count == 1)
    }

    @Test func currentLocationWithoutAKnownFixSkipsTheRefresh() async {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))
        harness.selection = .currentLocation
        harness.lastKnownGPSCoordinate = nil

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .skippedNoCoordinate)
        #expect(await harness.fetcher.weatherRequests.isEmpty)
        #expect(harness.published.isEmpty)
    }

    @Test func weatherFetchFailureLeavesExistingSnapshotUnpublished() async {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        await harness.fetcher.failWeather()

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .failed)
        #expect(harness.published.isEmpty)
    }

    @Test func onDeviceModelFailureLeavesExistingSnapshotUnpublished() async {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        await harness.fetcher.failRecommendation()

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .failed)
        #expect(harness.published.isEmpty)
    }

    @Test func snapshotFromBeforeLocalMidnightIsStaleEvenWhenSameDayInUTC() async {
        // 23:30 and 00:15 Pacific are both Oct 8 in UTC, but different days on the device.
        let harness = Harness(now: date("2026-10-08T00:15:00-07:00"))
        harness.timeZone = pacific
        harness.snapshot = .generated(at: date("2026-10-07T23:30:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)

        #expect(await harness.refresher.refreshIfStale() == .refreshed)
    }

    @Test func snapshotFromEarlierTodayInDeviceZoneIsCurrentEvenWhenYesterdayInUTC() async {
        // 08:00 and 20:00 Tokyo are the same local day, but 08:00 is still Oct 7 in UTC.
        let harness = Harness(now: date("2026-10-08T20:00:00+09:00"))
        harness.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        harness.snapshot = .generated(at: date("2026-10-08T08:00:00+09:00"))
        harness.selection = .custom(name: "Tokyo", latitude: 35.7, longitude: 139.7)

        #expect(await harness.refresher.refreshIfStale() == .alreadyCurrent)
        #expect(await harness.fetcher.weatherRequests.isEmpty)
    }

    @Test func nextRequestIsJustAfterTheNextLocalMidnight() {
        let harness = Harness(now: date("2026-10-08T15:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-08T07:00:00-07:00"))

        #expect(harness.refresher.nextRequestDate() == date("2026-10-09T00:05:00-07:00"))
    }

    @Test func nextRequestRetriesWithinTheHourWhileThePlanIsStillStale() {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))

        #expect(harness.refresher.nextRequestDate() == date("2026-10-08T07:00:00-07:00"))
    }
}

// MARK: - Harness

private let pacific = TimeZone(identifier: "America/Los_Angeles")!

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

@MainActor
private final class Harness {
    let fetcher = RecordingPlanFetcher()
    var now: Date
    var timeZone = pacific
    var snapshot: PlanSnapshot?
    var selection: LocationSelection = .currentLocation
    var lastKnownGPSCoordinate: CLLocationCoordinate2D?
    var provider: WeatherProvider = .apple
    private(set) var published: [PlanSnapshot] = []

    init(now: Date) {
        self.now = now
    }

    var refresher: BackgroundPlanRefresher {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return BackgroundPlanRefresher(
            fetcher: fetcher,
            calendar: calendar,
            now: { [unowned self] in now },
            loadSnapshot: { [unowned self] in snapshot },
            publish: { [unowned self] in published.append($0) },
            selection: { [unowned self] in selection },
            lastKnownGPSCoordinate: { [unowned self] in lastKnownGPSCoordinate },
            provider: { [unowned self] in provider }
        )
    }
}

private struct WeatherRequest: Equatable {
    let latitude: Double
    let longitude: Double
    let provider: WeatherProvider
}

private struct StubFailure: Error {}

private actor RecordingPlanFetcher: DayPlanFetching {
    private(set) var weatherRequests: [WeatherRequest] = []
    var weatherResult: Result<DailyWeather, StubFailure> = .success(.placeholder)
    var recommendationResult: Result<OutfitRecommendation, StubFailure> = .success(.placeholder)

    func failWeather() { weatherResult = .failure(StubFailure()) }
    func failRecommendation() { recommendationResult = .failure(StubFailure()) }

    func fetchWeather(for coordinate: CLLocationCoordinate2D, from provider: WeatherProvider) async throws -> (DailyWeather, HourlyForecast?) {
        weatherRequests.append(WeatherRequest(latitude: coordinate.latitude, longitude: coordinate.longitude, provider: provider))
        return (try weatherResult.get(), nil)
    }

    func recommendation(for weather: DailyWeather) async throws -> OutfitRecommendation {
        try recommendationResult.get()
    }
}

private extension PlanSnapshot {
    static func generated(at date: Date) -> PlanSnapshot {
        PlanSnapshot(weather: .placeholder, recommendation: .placeholder, generatedAt: date, provider: .apple)
    }
}
