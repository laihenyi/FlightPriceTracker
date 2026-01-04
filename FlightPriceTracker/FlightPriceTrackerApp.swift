import SwiftUI

@main
struct FlightPriceTrackerApp: App {
    @StateObject private var dataStore = DataStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 600)

        Settings {
            SettingsView()
                .environmentObject(dataStore)
        }
    }
}
