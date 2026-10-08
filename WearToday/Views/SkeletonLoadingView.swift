import SwiftUI

struct SkeletonLoadingView: View {
    @State private var shimmerPhase: CGFloat = -0.5

    var body: some View {
        DayPlanView(weather: .placeholder, recommendation: Self.recommendation, hourly: Self.hourly)
            .redacted(reason: .placeholder)
            .disabled(true)
            .modifier(ShimmerMask(phase: shimmerPhase))
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.5
                }
            }
    }
}

// Sized to match a typical loaded plan (hourly chart, two-sentence summary, five items)
// so the cards don't jump in height when real data arrives. Kept separate from the shared
// `.placeholder` values, which also back the widget gallery previews.
private extension SkeletonLoadingView {
    static let recommendation = OutfitRecommendation(
        summary: "Expect a mild start with clouds building through the afternoon. Dress in light layers and keep rain gear handy for the commute home.",
        items: [
            RecommendedItem(emoji: "🧥", name: "Light jacket", reason: "Cool morning air before the afternoon warms up"),
            RecommendedItem(emoji: "☂️", name: "Umbrella", reason: "Scattered showers are likely later in the day"),
            RecommendedItem(emoji: "🕶️", name: "Sunglasses", reason: "Bright sun breaks through around midday"),
            RecommendedItem(emoji: "👟", name: "Sneakers", reason: "Comfortable for walking on damp sidewalks"),
            RecommendedItem(emoji: "🧢", name: "Cap", reason: "Keeps sun and light drizzle off your face")
        ]
    )

    static let hourly: HourlyForecast = {
        let start = Calendar.current.dateInterval(of: .hour, for: .now)?.start ?? .now
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "h a"
        let points = (0..<24).map { hour in
            let date = start.addingTimeInterval(Double(hour) * 3600)
            let mean = 65 + 7 * sin(Double(hour) / 24 * 2 * .pi)
            return HourlyTemperaturePoint(
                date: date,
                hourLabel: labelFormatter.string(from: date),
                meanF: mean,
                minF: mean - 2,
                maxF: mean + 2,
                precipitationProbability: 20
            )
        }
        return HourlyForecast(timeZone: .current, points: points)
    }()
}

private struct ShimmerMask: ViewModifier, Animatable {
    var phase: CGFloat

    nonisolated var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        content.mask(
            LinearGradient(
                colors: [.black.opacity(0.4), .black, .black.opacity(0.4)],
                startPoint: UnitPoint(x: phase - 0.3, y: 0.5),
                endPoint: UnitPoint(x: phase + 0.3, y: 0.5)
            )
        )
    }
}

#Preview {
    SkeletonLoadingView()
        .padding()
        .environmentObject(TemperaturePreferenceStore())
        .environmentObject(CardPreferenceStore())
}
