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
            fetcher: fetcher
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
}

@MainActor
private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
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

    func requestLocation() {
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
