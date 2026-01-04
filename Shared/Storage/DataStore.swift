import Foundation
import Security

/// Centralized data storage using App Group for sharing between App and Widget
class DataStore: ObservableObject {
    static let shared = DataStore()

    // App Group identifier - update this with your actual App Group ID
    private let appGroupID = "group.com.flightpricetracker"
    private let routesKey = "monitored_routes"
    private let priceHistoryKey = "price_history"
    private let lastUpdateKey = "last_update"
    private let apiKeyService = "com.flightpricetracker.apikey"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    @Published var routes: [FlightRoute] = []
    @Published var priceHistories: [UUID: PriceHistory] = [:]
    @Published var lastUpdate: Date?
    @Published var isLoading = false

    private init() {
        loadData()
    }

    // MARK: - Routes Management

    /// Load all data from storage
    func loadData() {
        loadRoutes()
        loadPriceHistories()
        loadLastUpdate()
    }

    /// Save routes to storage
    func saveRoutes() {
        guard let defaults = userDefaults else { return }
        if let encoded = try? JSONEncoder().encode(routes) {
            defaults.set(encoded, forKey: routesKey)
        }
    }

    /// Load routes from storage
    private func loadRoutes() {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: routesKey),
              let decoded = try? JSONDecoder().decode([FlightRoute].self, from: data) else {
            // Initialize with default routes if none exist
            routes = FlightRoute.defaultRoutes
            saveRoutes()
            return
        }
        routes = decoded
    }

    /// Add or update a route
    func updateRoute(_ route: FlightRoute) {
        if let index = routes.firstIndex(where: { $0.id == route.id }) {
            routes[index] = route
        } else {
            routes.append(route)
        }
        saveRoutes()
    }

    /// Delete a route
    func deleteRoute(_ route: FlightRoute) {
        routes.removeAll { $0.id == route.id }
        priceHistories.removeValue(forKey: route.id)
        saveRoutes()
        savePriceHistories()
    }

    // MARK: - Price History Management

    /// Save price histories to storage
    func savePriceHistories() {
        guard let defaults = userDefaults else { return }
        let histories = Array(priceHistories.values)
        if let encoded = try? JSONEncoder().encode(histories) {
            defaults.set(encoded, forKey: priceHistoryKey)
        }
    }

    /// Load price histories from storage
    private func loadPriceHistories() {
        guard let defaults = userDefaults,
              let data = defaults.data(forKey: priceHistoryKey),
              let decoded = try? JSONDecoder().decode([PriceHistory].self, from: data) else {
            return
        }
        priceHistories = Dictionary(uniqueKeysWithValues: decoded.map { ($0.routeId, $0) })
    }

    /// Add a new price to history
    func addPrice(_ price: FlightPrice) {
        if var history = priceHistories[price.routeId] {
            history.addPrice(price)
            priceHistories[price.routeId] = history
        } else {
            var newHistory = PriceHistory(routeId: price.routeId)
            newHistory.addPrice(price)
            priceHistories[price.routeId] = newHistory
        }
        savePriceHistories()
    }

    /// Get price change for a route
    func getPriceChange(for routeId: UUID) -> PriceChange? {
        guard let history = priceHistories[routeId] else { return nil }
        return PriceChange(from: history)
    }

    /// Get latest price for a route
    func getLatestPrice(for routeId: UUID) -> FlightPrice? {
        priceHistories[routeId]?.latestPrice
    }

    /// Get previous price for a route
    func getPreviousPrice(for routeId: UUID) -> FlightPrice? {
        priceHistories[routeId]?.previousPrice
    }

    // MARK: - Last Update

    /// Save last update time
    func updateLastUpdateTime() {
        lastUpdate = Date()
        userDefaults?.set(lastUpdate, forKey: lastUpdateKey)
    }

    /// Load last update time
    private func loadLastUpdate() {
        lastUpdate = userDefaults?.object(forKey: lastUpdateKey) as? Date
    }

    // MARK: - API Key (Keychain)

    /// Save API key to Keychain
    func saveApiKey(_ apiKey: String) -> Bool {
        let data = apiKey.data(using: .utf8)!

        // Delete existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Load API key from Keychain
    func loadApiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }

        return apiKey
    }

    /// Delete API key from Keychain
    func deleteApiKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Check if API key exists
    var hasApiKey: Bool {
        loadApiKey() != nil
    }

    // MARK: - Refresh Data

    /// Fetch latest prices from API
    @MainActor
    func refreshPrices() async {
        guard let apiKey = loadApiKey(), !apiKey.isEmpty else {
            print("No API key configured")
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Store previous prices for comparison
        var previousPrices: [UUID: FlightPrice] = [:]
        for route in routes {
            previousPrices[route.id] = getLatestPrice(for: route.id)
        }

        let results = await SerpApiService.shared.fetchAllPrices(routes: routes, apiKey: apiKey)

        var currentPrices: [UUID: FlightPrice] = [:]

        for (index, result) in results.enumerated() {
            let route = routes.filter { $0.isEnabled }[index]
            switch result {
            case .success(let price):
                addPrice(price)
                currentPrices[route.id] = price
            case .failure(let error):
                print("Failed to fetch price for \(route.displayName): \(error)")
            }
        }

        updateLastUpdateTime()

        // Check for significant price drops and notify
        NotificationService.shared.checkAndNotify(
            routes: routes,
            currentPrices: currentPrices,
            previousPrices: previousPrices
        )
    }
}
