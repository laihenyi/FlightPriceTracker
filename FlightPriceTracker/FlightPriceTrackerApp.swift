import SwiftUI
import ServiceManagement

@main
struct FlightPriceTrackerApp: App {
    @StateObject private var dataStore = DataStore.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main Window (hidden by default)
        Window("機票價格監控", id: "main") {
            ContentView()
                .environmentObject(dataStore)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 600)

        // Settings Window
        Settings {
            SettingsView()
                .environmentObject(dataStore)
        }

        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(dataStore)
        } label: {
            Image(systemName: "airplane")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start background scheduler
        BackgroundTaskScheduler.shared.start()

        // Close all windows on launch - only show menu bar
        DispatchQueue.main.async {
            for window in NSApp.windows {
                if window.title == "機票價格監控" || window.identifier?.rawValue.contains("main") == true {
                    window.close()
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running in menu bar even when all windows are closed
        return false
    }
}

// MARK: - Menu Bar View
struct MenuBarView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "airplane")
                Text("機票價格監控")
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.bottom, 4)

            Divider()

            // Route prices (all 7 routes)
            ForEach(dataStore.routes.filter { $0.isEnabled }) { route in
                MenuBarRouteRow(route: route)
            }

            Divider()

            // Actions
            Button("重新整理") {
                Task {
                    await dataStore.refreshPrices()
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("開啟主視窗") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("設定...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Toggle("開機自動啟動", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("Failed to update launch at login: \(error)")
                        launchAtLogin = !newValue // Revert on failure
                    }
                }

            Divider()

            Button("結束") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding()
        .frame(width: 280)
    }
}

struct MenuBarRouteRow: View {
    let route: FlightRoute
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        HStack {
            Text(route.displayName)
                .font(.subheadline)

            Text(route.destinationCity)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if let price = dataStore.getLatestPrice(for: route.id) {
                Text(price.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let change = dataStore.getPriceChange(for: route.id) {
                    Text(change.arrowIndicator + change.formattedChangePercent)
                        .font(.caption)
                        .foregroundColor(change.changeColor)
                }
            } else {
                Text("--")
                    .foregroundColor(.secondary)
            }
        }
    }
}
