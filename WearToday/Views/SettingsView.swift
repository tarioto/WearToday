import SwiftUI
import CoreLocation

struct SettingsView: View {
    @ObservedObject var preference: LocationPreferenceStore
    @ObservedObject var temperaturePreference: TemperaturePreferenceStore
    @ObservedObject var cardPreference: CardPreferenceStore
    @ObservedObject var themePreference: ThemePreferenceStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Weather Location") {
                    Button {
                        preference.selection = .currentLocation
                        dismiss()
                    } label: {
                        HStack {
                            Label("Current Location", systemImage: "location.fill")
                            Spacer()
                            if case .currentLocation = preference.selection {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section {
                    HStack {
                        TextField("City name", text: $searchText)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onSubmit { search() }
                        if isSearching {
                            ProgressView()
                        }
                    }

                    Button("Use This City") {
                        search()
                    }
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if case .custom(let name, _, _) = preference.selection {
                        HStack {
                            Label(name, systemImage: "mappin.and.ellipse")
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                } header: {
                    Text("Custom City")
                } footer: {
                    Text("Search for a city to see its weather instead of your current location.")
                }

                Section("Temperature Unit") {
                    Picker("Temperature Unit", selection: $temperaturePreference.unit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            ForEach(AppTheme.allCases) { theme in
                                Button {
                                    themePreference.theme = theme
                                } label: {
                                    VStack(spacing: 6) {
                                        Circle()
                                            .fill(theme.swatchGradient)
                                            .frame(width: 46, height: 46)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(
                                                        Color.primary,
                                                        lineWidth: themePreference.theme == theme ? 3 : 0
                                                    )
                                            )
                                            .overlay {
                                                if themePreference.theme == theme {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                        Text(theme.label)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    Picker("Appearance", selection: $themePreference.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.label).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } header: {
                    Text("Theme")
                } footer: {
                    Text("The color is used for the home screen background. Appearance controls Light/Dark mode independently.")
                }

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
                } header: {
                    Text("Home Screen Cards")
                } footer: {
                    Text("Drag to reorder. Turn off a card to hide it from the home screen.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func search() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        Task {
            do {
                let placemarks = try await CLGeocoder().geocodeAddressString(query)
                guard let placemark = placemarks.first, let location = placemark.location else {
                    throw GeocodeError.notFound
                }
                let displayName = [placemark.locality, placemark.administrativeArea, placemark.country]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                preference.selection = .custom(
                    name: displayName.isEmpty ? query : displayName,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                isSearching = false
                dismiss()
            } catch {
                isSearching = false
                errorMessage = "Couldn't find that location. Try a different search."
            }
        }
    }
}

private enum GeocodeError: Error {
    case notFound
}

#Preview {
    SettingsView(
        preference: LocationPreferenceStore(),
        temperaturePreference: TemperaturePreferenceStore(),
        cardPreference: CardPreferenceStore(),
        themePreference: ThemePreferenceStore()
    )
}
