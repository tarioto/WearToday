import Foundation

@MainActor
final class TemperaturePreferenceStore: ObservableObject {
    @Published var unit: TemperatureUnit {
        didSet { SharedStore.saveTemperatureUnit(unit) }
    }

    init() {
        unit = SharedStore.loadTemperatureUnit()
    }
}
