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
    private let apiProviderKey = "api_provider"
    private let apiKeyService = "com.flightpricetracker.apikey"
    private let amadeusClientIdService = "com.flightpricetracker.amadeus.clientid"
    private let amadeusClientSecretService = "com.flightpricetracker.amadeus.clientsecret"

    /// API Provider options
    enum ApiProvider: String, CaseIterable {
        case serpApi = "SerpApi"
        case amadeus = "Amadeus"
    }

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    @Published var routes: [FlightRoute] = []
    @Published var priceHistories: [UUID: PriceHistory] = [:]
    @Published var lastUpdate: Date?
    @Published var isLoading = false
    @Published var selectedApiProvider: ApiProvider = .serpApi

    private init() {
        loadData()
        loadApiProvider()
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

        // Check if stored routes have outdated dates, update if needed
        let defaultRoutes = FlightRoute.defaultRoutes
        if let firstDefault = defaultRoutes.first,
           let firstStored = decoded.first,
           firstDefault.outboundDate != firstStored.outboundDate || firstDefault.returnDate != firstStored.returnDate {
            // Dates have changed, update to new defaults while preserving enabled states
            routes = defaultRoutes.map { defaultRoute in
                var newRoute = defaultRoute
                if let storedRoute = decoded.first(where: { $0.arrivalAirport == defaultRoute.arrivalAirport }) {
                    newRoute = FlightRoute(
                        id: storedRoute.id, // Preserve ID to keep price history linkage
                        departureAirport: defaultRoute.departureAirport,
                        arrivalAirport: defaultRoute.arrivalAirport,
                        destinationCity: defaultRoute.destinationCity,
                        outboundDate: defaultRoute.outboundDate,
                        returnDate: defaultRoute.returnDate,
                        isEnabled: storedRoute.isEnabled
                    )
                }
                return newRoute
            }
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

    // MARK: - Amadeus Credentials

    /// Save Amadeus Client ID
    func saveAmadeusClientId(_ clientId: String) -> Bool {
        saveToKeychain(service: amadeusClientIdService, value: clientId)
    }

    /// Load Amadeus Client ID
    func loadAmadeusClientId() -> String? {
        loadFromKeychain(service: amadeusClientIdService)
    }

    /// Save Amadeus Client Secret
    func saveAmadeusClientSecret(_ clientSecret: String) -> Bool {
        saveToKeychain(service: amadeusClientSecretService, value: clientSecret)
    }

    /// Load Amadeus Client Secret
    func loadAmadeusClientSecret() -> String? {
        loadFromKeychain(service: amadeusClientSecretService)
    }

    /// Check if Amadeus credentials exist
    var hasAmadeusCredentials: Bool {
        loadAmadeusClientId() != nil && loadAmadeusClientSecret() != nil
    }

    // Generic Keychain helpers
    private func saveToKeychain(service: String, value: String) -> Bool {
        let data = value.data(using: .utf8)!

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func loadFromKeychain(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    // MARK: - API Provider Selection

    /// Save selected API provider
    func saveApiProvider(_ provider: ApiProvider) {
        selectedApiProvider = provider
        userDefaults?.set(provider.rawValue, forKey: apiProviderKey)
    }

    /// Load selected API provider
    private func loadApiProvider() {
        if let rawValue = userDefaults?.string(forKey: apiProviderKey),
           let provider = ApiProvider(rawValue: rawValue) {
            selectedApiProvider = provider
        }
    }

    // MARK: - Refresh Data

    private func log(_ message: String) {
        let logFile = "/tmp/flightpricetracker.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile) {
                if let handle = FileHandle(forWritingAtPath: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logFile, contents: data)
            }
        }
    }

    /// Fetch latest prices from API
    @MainActor
    func refreshPrices() async {
        log("🔄 refreshPrices() called with provider: \(selectedApiProvider.rawValue)")

        isLoading = true
        defer { isLoading = false }

        // Store previous prices for comparison
        var previousPrices: [UUID: FlightPrice] = [:]
        for route in routes {
            previousPrices[route.id] = getLatestPrice(for: route.id)
        }

        let results: [Result<FlightPrice, Error>]

        switch selectedApiProvider {
        case .serpApi:
            guard let apiKey = loadApiKey(), !apiKey.isEmpty else {
                log("❌ No SerpApi API key configured")
                return
            }
            log("✅ SerpApi Key loaded: \(apiKey.prefix(8))...")
            log("📍 Routes count: \(routes.count), enabled: \(routes.filter { $0.isEnabled }.count)")
            results = await SerpApiService.shared.fetchAllPrices(routes: routes, apiKey: apiKey)

        case .amadeus:
            guard let clientId = loadAmadeusClientId(),
                  let clientSecret = loadAmadeusClientSecret(),
                  !clientId.isEmpty, !clientSecret.isEmpty else {
                log("❌ No Amadeus credentials configured")
                return
            }
            log("✅ Amadeus credentials loaded")
            log("📍 Routes count: \(routes.count), enabled: \(routes.filter { $0.isEnabled }.count)")
            results = await AmadeusApiService.shared.fetchAllPrices(routes: routes, clientId: clientId, clientSecret: clientSecret)
        }

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
