import CoreLocation

/// The network and on-device model calls behind a day plan, so tests can stub them out.
protocol DayPlanFetching: Sendable {
    func fetchWeather(for coordinate: CLLocationCoordinate2D, from provider: WeatherProvider) async throws -> (DailyWeather, HourlyForecast?)
    func recommendation(for weather: DailyWeather) async throws -> OutfitRecommendation
}

struct DayPlanFetcher: DayPlanFetching {
    private let weatherService = WeatherService()
    private let hourlyForecastService = HourlyForecastService()
    private let appleWeatherService = AppleWeatherService()
    private let outfitAdvisor = OutfitAdvisor()

    func fetchWeather(for coordinate: CLLocationCoordinate2D, from provider: WeatherProvider) async throws -> (DailyWeather, HourlyForecast?) {
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

    func recommendation(for weather: DailyWeather) async throws -> OutfitRecommendation {
        try await outfitAdvisor.recommendation(for: weather)
    }
}
