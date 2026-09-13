import Foundation

enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case fahrenheit
    case celsius

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fahrenheit: return "Fahrenheit"
        case .celsius: return "Celsius"
        }
    }

    var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }

    func displayString(fromFahrenheit value: Double) -> String {
        "\(Int(convert(fromFahrenheit: value).rounded()))°"
    }

    private func convert(fromFahrenheit value: Double) -> Double {
        switch self {
        case .fahrenheit: return value
        case .celsius: return (value - 32) * 5 / 9
        }
    }
}
