import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationPreference = LocationPreferenceStore()
    @StateObject private var temperaturePreference = TemperaturePreferenceStore()
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
        .background(Color(.systemGroupedBackground))
        .environmentObject(temperaturePreference)
        .onAppear { viewModel.start() }
        .sheet(isPresented: $showingSettings) {
            SettingsView(preference: locationPreference, temperaturePreference: temperaturePreference)
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
        case .loaded(let weather, let recommendation):
            DayPlanView(weather: weather, recommendation: recommendation)
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
