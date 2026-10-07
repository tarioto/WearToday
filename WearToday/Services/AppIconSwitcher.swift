import StoreKit
import UIKit

/// Shows the beta app icon on TestFlight installs and the default icon everywhere else.
/// Xcode (Debug) builds get their dev icon at build time via ASSETCATALOG_COMPILER_APPICON_NAME.
enum AppIconSwitcher {
    private static let betaIconName = "AppIcon-Beta"

    @MainActor
    static func applyForInstallSource() async {
        guard UIApplication.shared.supportsAlternateIcons,
              case .verified(let transaction) = try? await AppTransaction.shared else { return }

        let desired: String?
        switch transaction.environment {
        case .sandbox: desired = betaIconName  // TestFlight
        case .production: desired = nil
        default: return  // Xcode builds already use the dev icon
        }

        guard UIApplication.shared.alternateIconName != desired else { return }
        try? await UIApplication.shared.setAlternateIconName(desired)
    }
}
