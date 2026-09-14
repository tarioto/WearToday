import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationPreference = LocationPreferenceStore()
    @StateObject private var temperaturePreference = TemperaturePreferenceStore()
    @StateObject private var cardPreference = CardPreferenceStore()
    @StateObject private var themePreference = ThemePreferenceStore()
    @StateObject private var viewModel: DayPlanViewModel
    @State private var showingSettings = false

    init() {
        let manager = LocationManager()
        let preference = LocationPreferenceStore()
        _locationManager = StateObject(wrappedValue: manager)
        _locationPreference = StateObject(wrappedValue: preference)
        _viewModel = StateObject(wrappedValue: DayPlanViewModel(locationManager: manager, locationPreference: preference))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("WearToday")
                    .font(.largeTitle.bold())
                Spacer()
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(isRefreshing)
                .accessibilityLabel("Refresh")

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                content
                    .padding()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .background(themeBackground)
        .environmentObject(temperaturePreference)
        .environmentObject(cardPreference)
        .tint(themePreference.theme.accentColor)
        .preferredColorScheme(themePreference.appearance.colorScheme)
        .onAppear { viewModel.start() }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                preference: locationPreference,
                temperaturePreference: temperaturePreference,
                cardPreference: cardPreference,
                themePreference: themePreference
            )
        }
    }

    @ViewBuilder
    private var themeBackground: some View {
        if let colors = themePreference.theme.gradientColors {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        } else {
            Color(.systemGroupedBackground)
        }
    }

    private var isRefreshing: Bool {
        switch viewModel.state {
        case .loadingWeather, .loadingRecommendation:
            return true
        case .idle, .loaded, .failed:
            return false
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loadingWeather, .loadingRecommendation:
            SkeletonLoadingView()
        case .loaded(let weather, let recommendation, let hourly):
            DayPlanView(weather: weather, recommendation: recommendation, hourly: hourly)
        case .failed(let message):
            ErrorStateView(message: message) {
                viewModel.retry()
            }
            .padding(.top, 60)
        }
    }
}

#Preview {
    ContentView()
}
