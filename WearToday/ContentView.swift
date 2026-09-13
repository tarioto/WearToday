import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var locationPreference = LocationPreferenceStore()
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
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
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
        .onAppear { viewModel.start() }
        .sheet(isPresented: $showingSettings) {
            SettingsView(preference: locationPreference)
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
