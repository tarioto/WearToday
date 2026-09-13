import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel: DayPlanViewModel

    init() {
        let manager = LocationManager()
        _locationManager = StateObject(wrappedValue: manager)
        _viewModel = StateObject(wrappedValue: DayPlanViewModel(locationManager: manager))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("WearToday")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                content
                    .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { viewModel.start() }
        .onReceive(locationManager.$coordinate) { newValue in
            viewModel.handleLocationUpdate(newValue, errorMessage: locationManager.errorMessage)
        }
        .onReceive(locationManager.$errorMessage) { newValue in
            viewModel.handleLocationUpdate(locationManager.coordinate, errorMessage: newValue)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loadingWeather, .loadingRecommendation:
            SkeletonLoadingView()
        case .loaded(let weather, let recommendation):
            DayPlanView(weather: weather, recommendation: recommendation) {
                viewModel.retry()
            }
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
