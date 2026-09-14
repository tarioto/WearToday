import SwiftUI

/// Purely the home screen's background color choice.
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case none
    case sunset
    case ocean
    case aurora
    case midnight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Default"
        case .sunset: return "Sunset"
        case .ocean: return "Ocean"
        case .aurora: return "Aurora"
        case .midnight: return "Midnight"
        }
    }

    /// nil means "use the plain system-grouped background" (no gradient theme).
    var gradientColors: [Color]? {
        switch self {
        case .none:
            return nil
        case .sunset:
            return [
                Color(red: 1.00, green: 0.60, blue: 0.35),
                Color(red: 0.90, green: 0.30, blue: 0.45),
                Color(red: 0.40, green: 0.15, blue: 0.55)
            ]
        case .ocean:
            return [
                Color(red: 0.10, green: 0.65, blue: 0.80),
                Color(red: 0.08, green: 0.40, blue: 0.70),
                Color(red: 0.06, green: 0.18, blue: 0.48)
            ]
        case .aurora:
            return [
                Color(red: 0.20, green: 0.80, blue: 0.60),
                Color(red: 0.25, green: 0.50, blue: 0.85),
                Color(red: 0.45, green: 0.30, blue: 0.80)
            ]
        case .midnight:
            return [
                Color(red: 0.10, green: 0.10, blue: 0.22),
                Color(red: 0.18, green: 0.12, blue: 0.32),
                Color(red: 0.05, green: 0.05, blue: 0.13)
            ]
        }
    }

    var accentColor: Color {
        switch self {
        case .none: return .accentColor
        case .sunset: return Color(red: 1.00, green: 0.60, blue: 0.35)
        case .ocean: return Color(red: 0.30, green: 0.75, blue: 0.90)
        case .aurora: return Color(red: 0.35, green: 0.85, blue: 0.65)
        case .midnight: return Color(red: 0.65, green: 0.55, blue: 0.95)
        }
    }

    var swatchGradient: LinearGradient {
        let colors = gradientColors ?? [Color(.systemGray4), Color(.systemGray2)]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

/// The overall Light/Dark appearance, independent of which background color is chosen.
enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// nil means "follow the device's current Light/Dark Mode setting".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
