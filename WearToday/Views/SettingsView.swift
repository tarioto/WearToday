import SwiftUI
import CoreLocation

struct SettingsView: View {
    @ObservedObject var preference: LocationPreferenceStore
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
            }
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
    SettingsView(preference: LocationPreferenceStore())
}
