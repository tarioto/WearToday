import CoreLocation
import Combine
import WidgetKit

enum LoadState {
    case idle
    case loadingWeather
    case loadingRecommendation
    case loaded(weather: DailyWeather, recommendation: OutfitRecommendation)
    case failed(String)
}

@MainActor
final class DayPlanViewModel: ObservableObject {
    @Published private(set) var state: LoadState = .idle

    private let locationManager: LocationManager
    private let locationPreference: LocationPreferenceStore
    private let weatherService = WeatherService()
    private let outfitAdvisor = OutfitAdvisor()
    private var hasStarted = false
    private var lastCoordinate: CLLocationCoordinate2D?
    private var cancellables = Set<AnyCancellable>()

    init(locationManager: LocationManager, locationPreference: LocationPreferenceStore) {
        self.locationManager = locationManager
        self.locationPreference = locationPreference

        locationManager.$coordinate
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.handleGPSCoordinate(coordinate)
            }
            .store(in: &cancellables)

        locationManager.$errorMessage
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
        do {
            let weather = try await weatherService.fetchTodayForecast(for: coordinate)
            state = .loadingRecommendation
            let recommendation = try await outfitAdvisor.recommendation(for: weather)
            state = .loaded(weather: weather, recommendation: recommendation)
            lastCoordinate = coordinate
            SharedStore.save(PlanSnapshot(weather: weather, recommendation: recommendation, generatedAt: .now))
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
