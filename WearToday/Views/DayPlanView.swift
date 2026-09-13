import SwiftUI

struct DayPlanView: View {
    let weather: DailyWeather
    let recommendation: OutfitRecommendation
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            weatherHeader

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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Button(action: onRefresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
    }

    private var weatherHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weather.conditionDescription)
                    .font(.title2.bold())
                Text("H:\(Int(weather.highTemperatureF.rounded()))° L:\(Int(weather.lowTemperatureF.rounded()))°  •  \(weather.precipitationProbability)% rain  •  UV \(Int(weather.uvIndex.rounded()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: WMOWeatherCode.symbolName(for: weather.conditionCode))
                .font(.system(size: 44))
                .symbolRenderingMode(.multicolor)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
