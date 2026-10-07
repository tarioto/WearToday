import SwiftUI

@main
struct WearTodayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await AppIconSwitcher.applyForInstallSource() }
        }
    }
}
