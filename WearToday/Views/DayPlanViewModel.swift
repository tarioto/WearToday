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

    private let locationManager: LocationManager
    private let locationPreference: LocationPreferenceStore
    private let providerPreference: WeatherProviderPreferenceStore
    private let weatherService = WeatherService()
    private let hourlyForecastService = HourlyForecastService()
    private let appleWeatherService = AppleWeatherService()
    private let outfitAdvisor = OutfitAdvisor()
    private var hasStarted = false
    private var lastCoordinate: CLLocationCoordinate2D?
    private var cancellables = Set<AnyCancellable>()

    init(locationManager: LocationManager, locationPreference: LocationPreferenceStore, providerPreference: WeatherProviderPreferenceStore) {
        self.locationManager = locationManager
        self.locationPreference = locationPreference
        self.providerPreference = providerPreference

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
            let (weather, hourly) = try await fetchWeather(for: coordinate, from: provider)
            state = .loadingRecommendation
            let recommendation = try await outfitAdvisor.recommendation(for: weather)
            state = .loaded(weather: weather, recommendation: recommendation, hourly: hourly, provider: provider)
            lastCoordinate = coordinate
            SharedStore.save(PlanSnapshot(weather: weather, recommendation: recommendation, generatedAt: .now, provider: provider))
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func fetchWeather(for coordinate: CLLocationCoordinate2D, from provider: WeatherProvider) async throws -> (DailyWeather, HourlyForecast?) {
        switch provider {
        case .openMeteo:
            async let hourlyTask: HourlyForecast? = try? hourlyForecastService.fetchHourlyForecast(for: coordinate)
            let weather = try await weatherService.fetchTodayForecast(for: coordinate)
            return (weather, await hourlyTask)
        case .apple:
            // WeatherKit has no hourly uncertainty, so borrow Open-Meteo's ensemble spread
            // for the chart's band. If that request fails, the chart just shows the line.
            async let ensembleTask: HourlyForecast? = try? hourlyForecastService.fetchHourlyForecast(for: coordinate, includePrecipitation: false)
            let forecast = try await appleWeatherService.fetchForecast(for: coordinate)
            guard let ensemble = await ensembleTask else { return (forecast.daily, forecast.hourly) }
            return (forecast.daily, forecast.hourly.applyingSpread(from: ensemble))
        }
    }
}
