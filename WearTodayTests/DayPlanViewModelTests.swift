import Combine
import CoreLocation
import Testing
@testable import WearToday

@MainActor
struct DayPlanViewModelTests {
    @Test func pullToRefreshAfterLocationFailureLoadsPlanOnceLocationArrives() async throws {
        let location = FakeLocationProvider()
        let fetcher = FakeDayPlanFetcher()
        let locationPreference = LocationPreferenceStore()
        locationPreference.selection = .currentLocation
        let viewModel = DayPlanViewModel(
            locationManager: location,
            locationPreference: locationPreference,
            providerPreference: WeatherProviderPreferenceStore(),
            fetcher: fetcher,
            publishSnapshot: { _ in }
        )

        viewModel.start()
        location.fail("Couldn't find your location right now.")
        #expect(viewModel.state.isFailed)

        await viewModel.refresh()
        let coordinate = CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3)
        location.deliver(coordinate)

        try await waitUntil { viewModel.state.isLoaded }
        let requested = await fetcher.requestedCoordinates
        #expect(requested.map(\.latitude) == [47.6])
        #expect(requested.map(\.longitude) == [-122.3])
    }

    @Test func refreshInCurrentLocationAfterCustomCityDoesNotReloadThatCity() async throws {
        let location = FakeLocationProvider()
        let fetcher = FakeDayPlanFetcher()
        let locationPreference = LocationPreferenceStore()
        locationPreference.selection = .custom(name: "City A", latitude: 10, longitude: 10)
        var snapshots: [PlanSnapshot] = []
        let viewModel = DayPlanViewModel(
            locationManager: location,
            locationPreference: locationPreference,
            providerPreference: WeatherProviderPreferenceStore(),
            fetcher: fetcher,
            publishSnapshot: { snapshots.append($0) }
        )

        viewModel.start()
        try await waitUntil { viewModel.state.isLoaded }

        locationPreference.selection = .currentLocation
        location.fail("Couldn't find your location right now.")
        #expect(viewModel.state.isFailed)
        let requestsBeforeRefresh = location.locationRequestCount

        await viewModel.refresh()

        let requested = await fetcher.requestedCoordinates
        #expect(requested.map(\.latitude) == [10])
        #expect(location.locationRequestCount == requestsBeforeRefresh + 1)
        #expect(snapshots.count == 1)
    }

    @Test func refreshInCurrentLocationReloadsLastGPSFixWithoutNewLocationRequest() async throws {
        let location = FakeLocationProvider()
        let fetcher = FakeDayPlanFetcher()
        let locationPreference = LocationPreferenceStore()
        locationPreference.selection = .currentLocation
        let viewModel = DayPlanViewModel(
            locationManager: location,
            locationPreference: locationPreference,
            providerPreference: WeatherProviderPreferenceStore(),
            fetcher: fetcher,
            publishSnapshot: { _ in }
        )

        viewModel.start()
        location.deliver(CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3))
        try await waitUntil { viewModel.state.isLoaded }
        let requestsBeforeRefresh = location.locationRequestCount

        await viewModel.refresh()

        let requested = await fetcher.requestedCoordinates
        #expect(requested.map(\.latitude) == [47.6, 47.6])
        #expect(location.locationRequestCount == requestsBeforeRefresh)
    }

    @Test func refreshAfterReturningToCurrentLocationRequestsNewFixInsteadOfReloadingOldOne() async throws {
        let location = FakeLocationProvider()
        let fetcher = FakeDayPlanFetcher()
        let locationPreference = LocationPreferenceStore()
        locationPreference.selection = .currentLocation
        var snapshots: [PlanSnapshot] = []
        let viewModel = DayPlanViewModel(
            locationManager: location,
            locationPreference: locationPreference,
            providerPreference: WeatherProviderPreferenceStore(),
            fetcher: fetcher,
            publishSnapshot: { snapshots.append($0) }
        )

        viewModel.start()
        location.deliver(CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3))
        try await waitUntil { viewModel.state.isLoaded }

        locationPreference.selection = .custom(name: "City A", latitude: 10, longitude: 10)
        try await waitUntil { viewModel.state.isLoaded }

        locationPreference.selection = .currentLocation
        let requestsBeforeRefresh = location.locationRequestCount

        await viewModel.refresh()

        let requested = await fetcher.requestedCoordinates
        #expect(requested.map(\.latitude) == [47.6, 10])
        #expect(location.locationRequestCount == requestsBeforeRefresh + 1)
        #expect(snapshots.count == 2)
    }

    @Test func refreshForCustomCityReloadsThatCity() async throws {
        let fetcher = FakeDayPlanFetcher()
        let locationPreference = LocationPreferenceStore()
        locationPreference.selection = .custom(name: "City A", latitude: 10, longitude: 10)
        let viewModel = DayPlanViewModel(
            locationManager: FakeLocationProvider(),
            locationPreference: locationPreference,
            providerPreference: WeatherProviderPreferenceStore(),
            fetcher: fetcher,
            publishSnapshot: { _ in }
        )

        viewModel.start()
        try await waitUntil { viewModel.state.isLoaded }

        await viewModel.refresh()

        let requested = await fetcher.requestedCoordinates
        #expect(requested.map(\.latitude) == [10, 10])
    }

    @Test func slowLoadForPreviousCityDoesNotOverwriteNewerCity() async throws {
        let fetcher = GatedDayPlanFetcher()
        let locationPreference = LocationPreferenceStore()
        locationPreference.selection = .custom(name: "City A", latitude: 10, longitude: 10)
        var snapshots: [PlanSnapshot] = []
        let viewModel = DayPlanViewModel(
            locationManager: FakeLocationProvider(),
            locationPreference: locationPreference,
            providerPreference: WeatherProviderPreferenceStore(),
            fetcher: fetcher,
            publishSnapshot: { snapshots.append($0) }
        )

        let loadA = Task { await viewModel.refresh() }
        try await waitUntil { await fetcher.isWaiting(onLatitude: 10) }

        locationPreference.selection = .custom(name: "City B", latitude: 20, longitude: 20)
        try await waitUntil { await fetcher.isWaiting(onLatitude: 20) }

        await fetcher.complete(latitude: 20, with: .success(.forecast(high: 20)))
        try await waitUntil { viewModel.state.loadedHigh == 20 }

        await fetcher.complete(latitude: 10, with: .success(.forecast(high: 10)))
        await loadA.value

        #expect(viewModel.state.loadedHigh == 20)
        #expect(snapshots.map(\.weather.highTemperatureF) == [20])
    }

    @Test func supersededLoadThatFailsDoesNotReplaceNewerPlan() async throws {
        let fetcher = GatedDayPlanFetcher()
        let locationPreference = LocationPreferenceStore()
        locationPreference.selection = .custom(name: "City A", latitude: 10, longitude: 10)
        let viewModel = DayPlanViewModel(
            locationManager: FakeLocationProvider(),
            locationPreference: locationPreference,
            providerPreference: WeatherProviderPreferenceStore(),
            fetcher: fetcher,
            publishSnapshot: { _ in }
        )

        let loadA = Task { await viewModel.refresh() }
        try await waitUntil { await fetcher.isWaiting(onLatitude: 10) }

        locationPreference.selection = .custom(name: "City B", latitude: 20, longitude: 20)
        try await waitUntil { await fetcher.isWaiting(onLatitude: 20) }

        await fetcher.complete(latitude: 20, with: .success(.forecast(high: 20)))
        try await waitUntil { viewModel.state.loadedHigh == 20 }

        await fetcher.complete(latitude: 10, with: .failure(FakeFetchError()))
        await loadA.value

        #expect(viewModel.state.loadedHigh == 20)
    }

    @Test func pullToRefreshFinishesOnlyWhenTheRefreshedLoadFinishes() async throws {
        let fetcher = GatedDayPlanFetcher()
        let locationPreference = LocationPreferenceStore()
        locationPreference.selection = .custom(name: "City A", latitude: 10, longitude: 10)
        let viewModel = DayPlanViewModel(
            locationManager: FakeLocationProvider(),
            locationPreference: locationPreference,
            providerPreference: WeatherProviderPreferenceStore(),
            fetcher: fetcher,
            publishSnapshot: { _ in }
        )

        var refreshFinished = false
        let refresh = Task {
            await viewModel.refresh()
            refreshFinished = true
        }
        try await waitUntil { await fetcher.isWaiting(onLatitude: 10) }
        #expect(!refreshFinished)

        await fetcher.complete(latitude: 10, with: .success(.forecast(high: 10)))
        await refresh.value

        #expect(refreshFinished)
        #expect(viewModel.state.loadedHigh == 10)
    }
}

// MARK: - Helpers

private extension LoadState {
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }

    var loadedHigh: Double? {
        if case .loaded(let weather, _, _, _) = self { return weather.highTemperatureF }
        return nil
    }
}

private extension DailyWeather {
    static func forecast(high: Double) -> DailyWeather {
        DailyWeather(
            date: .now,
            highTemperatureF: high,
            lowTemperatureF: high - 10,
            precipitationProbability: 0,
            uvIndex: 0,
            windSpeedMph: 0,
            conditionCode: 0,
            conditionDescription: "Clear"
        )
    }
}

private struct FakeFetchError: LocalizedError {
    var errorDescription: String? { "Stale request failed" }
}

@MainActor
private func waitUntil(timeout: Duration = .seconds(2), _ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !(await condition()) {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out waiting for condition")
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

@MainActor
private final class FakeLocationProvider: LocationProviding {
    @Published private var coordinate: CLLocationCoordinate2D?
    @Published private var errorMessage: String?

    var coordinatePublisher: AnyPublisher<CLLocationCoordinate2D?, Never> { $coordinate.eraseToAnyPublisher() }
    var errorMessagePublisher: AnyPublisher<String?, Never> { $errorMessage.eraseToAnyPublisher() }

    private(set) var locationRequestCount = 0

    func requestLocation() {
        locationRequestCount += 1
        errorMessage = nil
    }

    func fail(_ message: String) {
        errorMessage = message
    }

    func deliver(_ coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

private actor FakeDayPlanFetcher: DayPlanFetching {
    private(set) var requestedCoordinates: [CLLocationCoordinate2D] = []

    func fetchWeather(for coordinate: CLLocationCoordinate2D, from provider: WeatherProvider) async throws -> (DailyWeather, HourlyForecast?) {
        requestedCoordinates.append(coordinate)
        return (.placeholder, nil)
    }

    func recommendation(for weather: DailyWeather) async throws -> OutfitRecommendation {
        .placeholder
    }
}

/// Holds each weather request until the test completes it, so tests control completion order.
private actor GatedDayPlanFetcher: DayPlanFetching {
    private var pending: [Double: CheckedContinuation<DailyWeather, Error>] = [:]

    func isWaiting(onLatitude latitude: Double) -> Bool {
        pending[latitude] != nil
    }

    func complete(latitude: Double, with result: Result<DailyWeather, Error>) {
        pending.removeValue(forKey: latitude)?.resume(with: result)
    }

    func fetchWeather(for coordinate: CLLocationCoordinate2D, from provider: WeatherProvider) async throws -> (DailyWeather, HourlyForecast?) {
        let weather = try await withCheckedThrowingContinuation { continuation in
            pending[coordinate.latitude] = continuation
        }
        return (weather, nil)
    }

    func recommendation(for weather: DailyWeather) async throws -> OutfitRecommendation {
        .placeholder
    }
}
