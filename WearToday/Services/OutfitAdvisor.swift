import Foundation
import FoundationModels

enum OutfitAdvisorError: Error, LocalizedError {
    case modelUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return reason
        }
    }
}

struct OutfitAdvisor {
    func recommendation(for weather: DailyWeather) async throws -> OutfitRecommendation {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw OutfitAdvisorError.modelUnavailable(Self.message(for: model.availability))
        }

        let session = LanguageModelSession(instructions: Instructions {
            """
            You are a friendly daily outfit and packing assistant. Given today's weather, \
            recommend what someone should wear and bring. Always consider sun protection \
            (sunglasses, sunscreen, hat), rain protection (umbrella, raincoat), and \
            temperature layering (light or heavy jacket) when relevant to the forecast. \
            Keep recommendations practical, specific, and concise.
            """
        })

        let prompt = """
        Today's forecast:
        - Condition: \(weather.conditionDescription)
        - High: \(Int(weather.highTemperatureF.rounded()))°F, Low: \(Int(weather.lowTemperatureF.rounded()))°F
        - Chance of precipitation: \(weather.precipitationProbability)%
        - UV index: \(weather.uvIndex)
        - Wind: \(Int(weather.windSpeedMph.rounded())) mph

        Recommend what to wear and bring today.
        """

        let response = try await session.respond(to: prompt, generating: OutfitRecommendation.self)
        return response.content
    }

    private static func message(for availability: SystemLanguageModel.Availability) -> String {
        guard case .unavailable(let reason) = availability else {
            return "AI recommendations aren't available right now."
        }
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to get AI recommendations."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        @unknown default:
            return "AI recommendations aren't available right now."
        }
    }
}
