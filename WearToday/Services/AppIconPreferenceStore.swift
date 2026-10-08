import StoreKit
import UIKit

/// Where the running copy of the app came from.
enum InstallSource {
    case dev
    case testFlight
    case appStore
}

/// Decides which home screen icon to show. With no Icon Choice, that's the Build Icon for the Install Source.
@MainActor
final class AppIconPreferenceStore {
    static let betaIconName = "AppIcon-Beta"

    private let supportsAlternateIcons: () -> Bool
    private let installSource: () async -> InstallSource?
    private let currentAlternateIconName: () -> String?
    private let setAlternateIconName: (String?) async -> Void

    init(
        supportsAlternateIcons: @escaping () -> Bool = { UIApplication.shared.supportsAlternateIcons },
        installSource: @escaping () async -> InstallSource? = AppIconPreferenceStore.verifiedInstallSource,
        currentAlternateIconName: @escaping () -> String? = { UIApplication.shared.alternateIconName },
        setAlternateIconName: @escaping (String?) async -> Void = { try? await UIApplication.shared.setAlternateIconName($0) }
    ) {
        self.supportsAlternateIcons = supportsAlternateIcons
        self.installSource = installSource
        self.currentAlternateIconName = currentAlternateIconName
        self.setAlternateIconName = setAlternateIconName
    }

    /// Shows the Build Icon, leaving the icon alone when the Install Source is unknown.
    func applyAtLaunch() async {
        guard supportsAlternateIcons(), let source = await installSource() else { return }

        let desired = Self.buildIconName(for: source)
        guard currentAlternateIconName() != desired else { return }
        await setAlternateIconName(desired)
    }

    /// The alternate icon name for the Build Icon, or nil for the primary icon.
    /// Debug builds' primary icon is already the Dev Icon via ASSETCATALOG_COMPILER_APPICON_NAME.
    private static func buildIconName(for source: InstallSource) -> String? {
        switch source {
        case .testFlight: betaIconName
        case .appStore, .dev: nil
        }
    }

    /// Default Install Source: the verified App Transaction's environment, or nil when it can't be verified.
    nonisolated static func verifiedInstallSource() async -> InstallSource? {
        guard case .verified(let transaction) = try? await AppTransaction.shared else { return nil }
        switch transaction.environment {
        case .xcode: return .dev
        case .sandbox: return .testFlight
        case .production: return .appStore
        default: return nil
        }
    }
}
