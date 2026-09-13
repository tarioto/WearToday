import CoreLocation
import Combine

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
    private let weatherService = WeatherService()
    private let outfitAdvisor = OutfitAdvisor()
    private var hasStarted = false

    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        locationManager.requestLocation()
    }

    func retry() {
        hasStarted = false
        state = .idle
        start()
    }

    func handleLocationUpdate(_ coordinate: CLLocationCoordinate2D?, errorMessage: String?) {
        if let errorMessage, coordinate == nil {
            state = .failed(errorMessage)
            return
        }
        guard let coordinate else { return }
        guard case .idle = state else { return }
        Task { await loadPlan(for: coordinate) }
    }

    private func loadPlan(for coordinate: CLLocationCoordinate2D) async {
        state = .loadingWeather
        do {
            let weather = try await weatherService.fetchTodayForecast(for: coordinate)
            state = .loadingRecommendation
            let recommendation = try await outfitAdvisor.recommendation(for: weather)
            state = .loaded(weather: weather, recommendation: recommendation)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
