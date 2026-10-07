import SwiftUI

struct DayPlanView: View {
    let weather: DailyWeather
    let recommendation: OutfitRecommendation
    var hourly: HourlyForecast? = nil
    var provider: WeatherProvider = .openMeteo
    @EnvironmentObject private var temperaturePreference: TemperaturePreferenceStore
    @EnvironmentObject private var cardPreference: CardPreferenceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(cardPreference.visibleOrderedTypes) { type in
                card(for: type)
            }

            WeatherAttributionView(provider: provider)
        }
    }

    @ViewBuilder
    private func card(for type: CardType) -> some View {
        switch type {
        case .weather:
            weatherCard
        case .plan:
            planCard
        case .wearAndBring:
            wearAndBringCard
        }
    }

    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weather")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weather.conditionDescription)
                        .font(.title2.bold())
                    Text("H:\(temperaturePreference.unit.displayString(fromFahrenheit: weather.highTemperatureF)) L:\(temperaturePreference.unit.displayString(fromFahrenheit: weather.lowTemperatureF))  •  \(weather.precipitationProbability)% rain  •  UV \(Int(weather.uvIndex.rounded()))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: WMOWeatherCode.symbolName(for: weather.conditionCode))
                    .font(.system(size: 44))
                    .symbolRenderingMode(.multicolor)
            }

            if let hourly {
                HourlyTemperatureChart(hourly: hourly)
            }
        }
        .padding()
        .cardGlass()
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's plan")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
            Divider()
            Text(recommendation.summary)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardGlass()
    }

    private var wearAndBringCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wear & bring")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
            Divider()

            VStack(spacing: 12) {
                ForEach(Array(recommendation.items.enumerated()), id: \.offset) { _, item in
                    ItemRow(item: item)
                }
            }
        }
        .padding()
        .cardGlass()
    }
}

private struct ItemRow: View {
    let item: RecommendedItem

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(item.emoji)
                .font(.system(size: 34))
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Text(item.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private extension View {
    func cardGlass() -> some View {
        glassEffect(in: .rect(cornerRadius: 16))
    }
}
