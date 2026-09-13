import SwiftUI

struct SkeletonLoadingView: View {
    @State private var shimmerPhase: CGFloat = -0.5

    var body: some View {
        DayPlanView(weather: .placeholder, recommendation: .placeholder)
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
}
