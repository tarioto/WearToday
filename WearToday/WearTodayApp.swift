import SwiftUI

@main
struct WearTodayApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await AppIconPreferenceStore().applyAtLaunch() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                BackgroundPlanRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(BackgroundPlanRefresh.taskIdentifier)) {
            await BackgroundPlanRefresh.run()
        }
    }
}
