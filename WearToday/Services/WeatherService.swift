import Foundation
import CoreLocation

enum WeatherServiceError: Error, LocalizedError {
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Couldn't reach the weather service. Check your connection and try again."
        case .decodingFailed:
            return "Received an unexpected response from the weather service."
        }
    }
}

struct WeatherService {
    func fetchTodayForecast(for coordinate: CLLocationCoordinate2D) async throws -> DailyWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max,windspeed_10m_max,weathercode"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "windspeed_unit", value: "mph"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]

        guard let url = components.url else { throw WeatherServiceError.invalidResponse }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherServiceError.invalidResponse
        }

        let decoded: OpenMeteoResponse
        do {
            decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        } catch {
            throw WeatherServiceError.decodingFailed
        }

        guard
            let dateString = decoded.daily.time.first,
            let high = decoded.daily.temperature_2m_max.first,
            let low = decoded.daily.temperature_2m_min.first,
            let precipitation = decoded.daily.precipitation_probability_max.first,
            let uv = decoded.daily.uv_index_max.first,
            let wind = decoded.daily.windspeed_10m_max.first,
            let code = decoded.daily.weathercode.first
        else {
            throw WeatherServiceError.decodingFailed
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: dateString) ?? Date()

        return DailyWeather(
            date: date,
            highTemperatureF: high,
            lowTemperatureF: low,
            precipitationProbability: precipitation,
            uvIndex: uv,
            windSpeedMph: wind,
            conditionCode: code,
            conditionDescription: WMOWeatherCode.description(for: code)
        )
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Daily: Decodable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_probability_max: [Int]
        let uv_index_max: [Double]
        let windspeed_10m_max: [Double]
        let weathercode: [Int]
    }
    let daily: Daily
}
