import Testing
@testable import WearToday

@MainActor
struct AppIconPreferenceStoreTests {
    private func makeStore(
        installSource: InstallSource?,
        currentIcon: String?,
        onSet: @escaping (String?) -> Void
    ) -> AppIconPreferenceStore {
        AppIconPreferenceStore(
            supportsAlternateIcons: { true },
            installSource: { installSource },
            currentAlternateIconName: { currentIcon },
            setAlternateIconName: { onSet($0) }
        )
    }

    @Test func testFlightLaunchSetsTheBetaIconWhenThePrimaryIconIsShowing() async {
        var setIcons: [String?] = []
        let store = makeStore(installSource: .testFlight, currentIcon: nil) { setIcons.append($0) }

        await store.applyAtLaunch()

        #expect(setIcons == [AppIconPreferenceStore.betaIconName])
    }

    @Test func appStoreLaunchResetsToThePrimaryIconWhenTheBetaIconIsShowing() async {
        var setIcons: [String?] = []
        let store = makeStore(installSource: .appStore, currentIcon: AppIconPreferenceStore.betaIconName) { setIcons.append($0) }

        await store.applyAtLaunch()

        #expect(setIcons == [nil])
    }

    @Test func devLaunchResetsToThePrimaryIconWhenTheBetaIconIsShowing() async {
        var setIcons: [String?] = []
        let store = makeStore(installSource: .dev, currentIcon: AppIconPreferenceStore.betaIconName) { setIcons.append($0) }

        await store.applyAtLaunch()

        #expect(setIcons == [nil])
    }

    @Test func launchWhereTheDesiredIconIsAlreadyShowingSetsNothing() async {
        var setIcons: [String?] = []
        let store = makeStore(installSource: .testFlight, currentIcon: AppIconPreferenceStore.betaIconName) { setIcons.append($0) }

        await store.applyAtLaunch()

        #expect(setIcons.isEmpty)
    }

    @Test func launchWithAnUnknownInstallSourceSetsNothing() async {
        var setIcons: [String?] = []
        let store = makeStore(installSource: nil, currentIcon: AppIconPreferenceStore.betaIconName) { setIcons.append($0) }

        await store.applyAtLaunch()

        #expect(setIcons.isEmpty)
    }

    @Test func launchWithoutAlternateIconSupportAttemptsNothing() async {
        var setIcons: [String?] = []
        var askedForInstallSource = false
        let store = AppIconPreferenceStore(
            supportsAlternateIcons: { false },
            installSource: { askedForInstallSource = true; return .testFlight },
            currentAlternateIconName: { nil },
            setAlternateIconName: { setIcons.append($0) }
        )

        await store.applyAtLaunch()

        #expect(setIcons.isEmpty)
        #expect(!askedForInstallSource)
    }
}
