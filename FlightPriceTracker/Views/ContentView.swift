import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingSettings = false
    @State private var showingRouteEditor = false
    @State private var selectedRoute: FlightRoute?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView

                Divider()

                // Route List
                if dataStore.routes.isEmpty {
                    emptyStateView
                } else {
                    routeListView
                }
            }
            .frame(minWidth: 450, minHeight: 500)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(dataStore)
        }
        .sheet(item: $selectedRoute) { route in
            RouteEditorView(route: route)
                .environmentObject(dataStore)
        }
        .task {
            // Request notification permission on launch
            _ = await NotificationService.shared.requestPermission()
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("機票價格監控")
                    .font(.title2)
                    .fontWeight(.bold)

                if let lastUpdate = dataStore.lastUpdate {
                    Text("上次更新: \(lastUpdate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("尚未更新")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                // Refresh Button
                Button(action: {
                    Task {
                        await dataStore.refreshPrices()
                    }
                }) {
                    if dataStore.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(dataStore.isLoading || !dataStore.hasApiKey)
                .help("立即更新價格")

                // Settings Button
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                }
                .help("設定")
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("尚無監控航線")
                .font(.headline)
                .foregroundColor(.secondary)

            if !dataStore.hasApiKey {
                Text("請先在設定中輸入 SerpApi API Key")
                    .font(.subheadline)
                    .foregroundColor(.orange)

                Button("前往設定") {
                    showingSettings = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Route List
    private var routeListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(dataStore.routes) { route in
                    RouteCardView(route: route)
                        .onTapGesture {
                            selectedRoute = route
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Route Card View
struct RouteCardView: View {
    let route: FlightRoute
    @EnvironmentObject var dataStore: DataStore

    private var latestPrice: FlightPrice? {
        dataStore.getLatestPrice(for: route.id)
    }

    private var priceChange: PriceChange? {
        dataStore.getPriceChange(for: route.id)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Route Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(route.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(route.destinationCity)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let price = latestPrice {
                    HStack(spacing: 4) {
                        Text(price.airline)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(price.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if price.stops > 0 {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("\(price.stops) 轉")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Price & Change
            VStack(alignment: .trailing, spacing: 4) {
                if let price = latestPrice {
                    Link(destination: route.googleFlightsURL) {
                        Text(price.formattedPrice)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("點擊在 Google Flights 搜尋")

                    if let change = priceChange {
                        HStack(spacing: 4) {
                            Text(change.arrowIndicator)
                            Text(change.formattedChangePercent)
                            if change.isSignificantDrop {
                                Text("🔔")
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(change.changeColor)
                    }
                } else {
                    Text("--")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("尚無資料")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Enable Toggle
            Toggle("", isOn: Binding(
                get: { route.isEnabled },
                set: { newValue in
                    var updatedRoute = route
                    updatedRoute.isEnabled = newValue
                    dataStore.updateRoute(updatedRoute)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .scaleEffect(0.8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(route.isEnabled ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(route.isEnabled ? 1 : 0.6)
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore.shared)
}
