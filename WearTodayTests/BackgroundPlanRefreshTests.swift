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

    @Test func onDeviceModelFailurePublishesWeatherOnlySnapshot() async {
        let now = date("2026-10-08T06:00:00-07:00")
        let harness = Harness(now: now)
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        await harness.fetcher.failRecommendation()

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .refreshedWeatherOnly)
        #expect(harness.published.count == 1)
        #expect(harness.published.first?.recommendation == nil)
        #expect(harness.published.first?.generatedAt == now)
    }

    @Test(arguments: [
        RecommendationState.UnavailableReason.deviceNotEligible,
        .appleIntelligenceNotEnabled,
        .modelNotReady,
    ])
    func unavailableModelPublishesWeatherOnlySnapshotWithoutAttemptingGeneration(reason: RecommendationState.UnavailableReason) async {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        await harness.fetcher.makeUnavailable(reason)

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .refreshedWeatherOnly)
        #expect(await harness.fetcher.recommendationRequestCount == 0)
        #expect(harness.published.count == 1)
        #expect(harness.published.first?.recommendation == nil)
    }

    @Test func todaysWeatherOnlySnapshotRetriesTheRecommendationOnceTheModelIsAvailable() async {
        // e.g. this morning's generation failed, or the model was still downloading.
        let harness = Harness(now: date("2026-10-08T09:00:00-07:00"))
        harness.snapshot = .weatherOnly(at: date("2026-10-08T06:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .refreshed)
        #expect(await harness.fetcher.recommendationRequestCount == 1)
        #expect(harness.published.count == 1)
        #expect(harness.published.first?.recommendation != nil)
    }

    @Test func todaysWeatherOnlySnapshotIsRefreshedWhileTheModelIsNotReadyYet() async {
        let now = date("2026-10-08T09:00:00-07:00")
        let harness = Harness(now: now)
        harness.snapshot = .weatherOnly(at: date("2026-10-08T06:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        await harness.fetcher.makeUnavailable(.modelNotReady)

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .refreshedWeatherOnly)
        #expect(await harness.fetcher.weatherRequests.count == 1)
        #expect(await harness.fetcher.recommendationRequestCount == 0)
        #expect(harness.published.map(\.generatedAt) == [now])
    }

    @Test(arguments: [
        RecommendationState.UnavailableReason.deviceNotEligible,
        .appleIntelligenceNotEnabled,
    ])
    func todaysWeatherOnlySnapshotIsFinalWhenTheModelIsPermanentlyUnavailable(reason: RecommendationState.UnavailableReason) async {
        let harness = Harness(now: date("2026-10-08T09:00:00-07:00"))
        harness.snapshot = .weatherOnly(at: date("2026-10-08T06:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        await harness.fetcher.makeUnavailable(reason)

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .alreadyCurrent)
        #expect(await harness.fetcher.weatherRequests.isEmpty)
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

    @Test func selectionChangedInTheAppDuringTheFetchIsNotOverwritten() async {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        await harness.fetcher.duringWeatherFetch { @MainActor in
            harness.selection = .custom(name: "Tokyo", latitude: 35.7, longitude: 139.7)
        }

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .supersededByApp)
        #expect(harness.published.isEmpty)
    }

    @Test func providerChangedInTheAppDuringTheFetchIsNotOverwritten() async {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        harness.provider = .openMeteo
        await harness.fetcher.duringWeatherFetch { @MainActor in
            harness.provider = .apple
        }

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .supersededByApp)
        #expect(harness.published.isEmpty)
    }

    @Test func todaysFullPlanSavedByTheAppDuringTheFetchIsNotReplacedWithWeatherOnly() async {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))
        harness.selection = .custom(name: "Seattle", latitude: 47.6, longitude: -122.3)
        await harness.fetcher.failRecommendation()
        let appPlanDate = date("2026-10-08T05:59:00-07:00")
        await harness.fetcher.duringWeatherFetch { @MainActor in
            harness.snapshot = .generated(at: appPlanDate)
        }

        let outcome = await harness.refresher.refreshIfStale()

        #expect(outcome == .supersededByApp)
        #expect(harness.published.isEmpty)
    }

    @Test func nextRequestIsJustAfterTheNextLocalMidnight() async {
        let harness = Harness(now: date("2026-10-08T15:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-08T07:00:00-07:00"))

        #expect(await harness.refresher.nextRequestDate() == date("2026-10-09T00:05:00-07:00"))
    }

    @Test(arguments: [
        RecommendationState.UnavailableReason.deviceNotEligible,
        .appleIntelligenceNotEnabled,
    ])
    func nextRequestWaitsForMidnightWhenTodaysWeatherOnlyPlanCantGetSuggestions(reason: RecommendationState.UnavailableReason) async {
        let harness = Harness(now: date("2026-10-08T15:00:00-07:00"))
        harness.snapshot = .weatherOnly(at: date("2026-10-08T07:00:00-07:00"))
        await harness.fetcher.makeUnavailable(reason)

        #expect(await harness.refresher.nextRequestDate() == date("2026-10-09T00:05:00-07:00"))
    }

    @Test(arguments: [RecommendationAvailability.available, .unavailable(.modelNotReady)])
    func nextRequestRetriesWithinTheHourWhileTodaysSuggestionsAreStillMissing(availability: RecommendationAvailability) async {
        let harness = Harness(now: date("2026-10-08T15:00:00-07:00"))
        harness.snapshot = .weatherOnly(at: date("2026-10-08T07:00:00-07:00"))
        await harness.fetcher.setAvailability(availability)

        #expect(await harness.refresher.nextRequestDate() == date("2026-10-08T16:00:00-07:00"))
    }

    @Test func nextRequestRetriesWithinTheHourWhileThePlanIsStillStale() async {
        let harness = Harness(now: date("2026-10-08T06:00:00-07:00"))
        harness.snapshot = .generated(at: date("2026-10-07T18:00:00-07:00"))

        #expect(await harness.refresher.nextRequestDate() == date("2026-10-08T07:00:00-07:00"))
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
    private(set) var recommendationRequestCount = 0
    var availability: RecommendationAvailability = .available
    var weatherResult: Result<DailyWeather, StubFailure> = .success(.placeholder)
    var recommendationResult: Result<OutfitRecommendation, StubFailure> = .success(.placeholder)

    func failWeather() { weatherResult = .failure(StubFailure()) }
    func failRecommendation() { recommendationResult = .failure(StubFailure()) }
    func makeUnavailable(_ reason: RecommendationState.UnavailableReason) { availability = .unavailable(reason) }
    func setAvailability(_ availability: RecommendationAvailability) { self.availability = availability }

    /// Runs `hook` inside `fetchWeather`, e.g. to simulate the user changing something in the app mid-fetch.
    private var weatherFetchHook: (@MainActor @Sendable () -> Void)?
    func duringWeatherFetch(_ hook: @escaping @MainActor @Sendable () -> Void) { weatherFetchHook = hook }

    func recommendationAvailability() async -> RecommendationAvailability {
        availability
    }

    func fetchWeather(for coordinate: CLLocationCoordinate2D, from provider: WeatherProvider) async throws -> (DailyWeather, HourlyForecast?) {
        weatherRequests.append(WeatherRequest(latitude: coordinate.latitude, longitude: coordinate.longitude, provider: provider))
        if let weatherFetchHook { await weatherFetchHook() }
        return (try weatherResult.get(), nil)
    }

    func recommendation(for weather: DailyWeather) async throws -> OutfitRecommendation {
        recommendationRequestCount += 1
        return try recommendationResult.get()
    }
}

private extension PlanSnapshot {
    static func generated(at date: Date) -> PlanSnapshot {
        PlanSnapshot(weather: .placeholder, recommendation: .placeholder, generatedAt: date, provider: .apple)
    }

    static func weatherOnly(at date: Date) -> PlanSnapshot {
        PlanSnapshot(weather: .placeholder, recommendation: nil, generatedAt: date, provider: .apple)
    }
}
