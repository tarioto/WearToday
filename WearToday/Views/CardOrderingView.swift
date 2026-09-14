import SwiftUI

struct CardOrderingView: View {
    @ObservedObject var cardPreference: CardPreferenceStore

    var body: some View {
        List {
            Section {
                ForEach($cardPreference.cards) { $config in
                    HStack {
                        Image(systemName: config.type.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(config.type.title)
                        Spacer()
                        Toggle("", isOn: $config.isVisible)
                            .labelsHidden()
                    }
                }
                .onMove { indices, newOffset in
                    cardPreference.cards.move(fromOffsets: indices, toOffset: newOffset)
                }
            } footer: {
                Text("Drag to reorder. Turn off a card to hide it from the home screen.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Home Screen Cards")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CardOrderingView(cardPreference: CardPreferenceStore())
    }
}
