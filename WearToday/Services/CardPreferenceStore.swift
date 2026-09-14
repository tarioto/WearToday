import Foundation

@MainActor
final class CardPreferenceStore: ObservableObject {
    @Published var cards: [CardConfig] {
        didSet { persist() }
    }

    private static let key = "cardConfiguration"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([CardConfig].self, from: data),
           Set(decoded.map(\.type)) == Set(CardType.allCases) {
            cards = decoded
        } else {
            cards = CardType.allCases.map { CardConfig(type: $0, isVisible: true) }
        }
    }

    var visibleOrderedTypes: [CardType] {
        cards.filter(\.isVisible).map(\.type)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
