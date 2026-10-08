import CoreLocation
import Combine
import WidgetKit

enum LoadState {
    case idle
    case loadingWeather
    case loadingRecommendation
    case loaded(weather: DailyWeather, recommendation: OutfitRecommendation, hourly: HourlyForecast?, provider: WeatherProvider)
    case failed(String)
}

@MainActor
final class DayPlanViewModel: ObservableObject {
    @Published private(set) var state: LoadState = .idle

    private let locationManager: LocationProviding
    private let locationPreference: LocationPreferenceStore
    private let providerPreference: WeatherProviderPreferenceStore
    private let fetcher: DayPlanFetching
    private var hasStarted = false
    private var lastCoordinate: CLLocationCoordinate2D?
    private var cancellables = Set<AnyCancellable>()

    init(locationManager: LocationProviding, locationPreference: LocationPreferenceStore, providerPreference: WeatherProviderPreferenceStore, fetcher: DayPlanFetching = DayPlanFetcher()) {
        self.locationManager = locationManager
        self.locationPreference = locationPreference
        self.providerPreference = providerPreference
        self.fetcher = fetcher

        locationManager.coordinatePublisher
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.handleGPSCoordinate(coordinate)
            }
            .store(in: &cancellables)

        locationManager.errorMessagePublisher
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.handleGPSError(message)
            }
            .store(in: &cancellables)

        locationPreference.$selection
            .dropFirst()
            .sink { [weak self] selection in
                self?.applySelection(selection)
            }
            .store(in: &cancellables)

        providerPreference.$provider
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self, self.hasStarted else { return }
                Task { await self.refresh() }
            }
            .store(in: &cancellables)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        beginLoading(for: locationPreference.selection)
    }

    func retry() {
        hasStarted = false
        state = .idle
        start()
    }

    func refresh() async {
        switch locationPreference.selection {
        case .currentLocation:
            if let lastCoordinate {
                await loadPlan(for: lastCoordinate)
            } else {
                // Leave .failed so handleGPSCoordinate loads the next fix.
                state = .idle
                locationManager.requestLocation()
            }
        case .custom(_, let latitude, let longitude):
            await loadPlan(for: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
    }

    private func beginLoading(for selection: LocationSelection) {
        switch selection {
        case .currentLocation:
            locationManager.requestLocation()
        case .custom(_, let latitude, let longitude):
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            Task { await loadPlan(for: coordinate) }
        }
    }

    private func applySelection(_ selection: LocationSelection) {
        hasStarted = true
        state = .idle
        beginLoading(for: selection)
    }

    private func handleGPSCoordinate(_ coordinate: CLLocationCoordinate2D) {
        guard case .currentLocation = locationPreference.selection else { return }
        lastCoordinate = coordinate
        guard case .idle = state else { return }
        Task { await loadPlan(for: coordinate) }
    }

    private func handleGPSError(_ message: String) {
        guard case .currentLocation = locationPreference.selection else { return }
        state = .failed(message)
    }

    private func loadPlan(for coordinate: CLLocationCoordinate2D) async {
        state = .loadingWeather
        // Read here (not in the provider sink, which fires before @Published updates).
        let provider = providerPreference.provider
        do {
            let (weather, hourly) = try await fetcher.fetchWeather(for: coordinate, from: provider)
            state = .loadingRecommendation
            let recommendation = try await fetcher.recommendation(for: weather)
            state = .loaded(weather: weather, recommendation: recommendation, hourly: hourly, provider: provider)
            lastCoordinate = coordinate
            SharedStore.save(PlanSnapshot(weather: weather, recommendation: recommendation, generatedAt: .now, provider: provider))
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
