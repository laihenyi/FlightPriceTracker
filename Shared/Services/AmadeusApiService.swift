import Foundation

/// Service for fetching flight prices from Amadeus API
actor AmadeusApiService {
    static let shared = AmadeusApiService()

    private let authURL = "https://test.api.amadeus.com/v1/security/oauth2/token"
    private let flightSearchURL = "https://test.api.amadeus.com/v2/shopping/flight-offers"
    private let session: URLSession

    // Token management
    private var accessToken: String?
    private var tokenExpiration: Date?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Authentication

    /// Get access token using client credentials
    private func getAccessToken(clientId: String, clientSecret: String) async throws -> String {
        // Check if we have a valid cached token
        if let token = accessToken, let expiration = tokenExpiration, Date() < expiration {
            return token
        }

        guard let url = URL(string: authURL) else {
            throw AmadeusApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=client_credentials&client_id=\(clientId)&client_secret=\(clientSecret)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmadeusApiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            log("❌ Auth failed with status: \(httpResponse.statusCode)")
            if let errorStr = String(data: data, encoding: .utf8) {
                log("❌ Auth error: \(errorStr)")
            }
            throw AmadeusApiError.authenticationFailed
        }

        let tokenResponse = try JSONDecoder().decode(AmadeusTokenResponse.self, from: data)

        // Cache the token
        accessToken = tokenResponse.accessToken
        tokenExpiration = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn - 60)) // 1 minute buffer

        log("✅ Amadeus token obtained, expires in \(tokenResponse.expiresIn)s")
        return tokenResponse.accessToken
    }

    // MARK: - Flight Search

    /// Fetch flight prices for a route
    func fetchFlightPrice(for route: FlightRoute, clientId: String, clientSecret: String) async throws -> FlightPrice {
        let token = try await getAccessToken(clientId: clientId, clientSecret: clientSecret)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Build URL with query parameters
        var components = URLComponents(string: flightSearchURL)!
        components.queryItems = [
            URLQueryItem(name: "originLocationCode", value: route.departureAirport),
            URLQueryItem(name: "destinationLocationCode", value: route.arrivalAirport),
            URLQueryItem(name: "departureDate", value: dateFormatter.string(from: route.outboundDate)),
            URLQueryItem(name: "returnDate", value: dateFormatter.string(from: route.returnDate)),
            URLQueryItem(name: "adults", value: "1"),
            URLQueryItem(name: "currencyCode", value: "TWD"),
            URLQueryItem(name: "max", value: "20")  // Get top 20 results
        ]

        guard let url = components.url else {
            throw AmadeusApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        log("📡 Fetching \(route.displayName) from Amadeus...")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmadeusApiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            log("❌ API error: \(httpResponse.statusCode)")
            if let errorStr = String(data: data, encoding: .utf8) {
                log("❌ Error body: \(errorStr.prefix(500))")
            }
            if httpResponse.statusCode == 401 {
                // Token expired, clear cache
                accessToken = nil
                tokenExpiration = nil
                throw AmadeusApiError.authenticationFailed
            }
            throw AmadeusApiError.httpError(statusCode: httpResponse.statusCode)
        }

        let apiResponse: AmadeusFlightResponse
        do {
            apiResponse = try JSONDecoder().decode(AmadeusFlightResponse.self, from: data)
        } catch {
            log("❌ Decoding error: \(error)")
            throw AmadeusApiError.decodingError(error.localizedDescription)
        }

        // Log diagnostic info
        log("📊 \(route.displayName): \(apiResponse.data.count) offers found")

        guard let cheapestOffer = apiResponse.data.first else {
            throw AmadeusApiError.noFlightsFound
        }

        // Parse price
        guard let price = Double(cheapestOffer.price.total) else {
            throw AmadeusApiError.decodingError("Invalid price format")
        }

        // Get airline from first segment
        let airline = cheapestOffer.itineraries.first?.segments.first?.carrierCode ?? "Unknown"
        let airlineName = apiResponse.dictionaries?.carriers?[airline] ?? airline

        // Calculate total duration
        let totalDuration = parseDuration(cheapestOffer.itineraries.first?.duration ?? "PT0H")

        // Count stops
        let stops = (cheapestOffer.itineraries.first?.segments.count ?? 1) - 1

        // Log prices
        let allPrices = apiResponse.data.prefix(5).compactMap { Double($0.price.total) }.map { Int($0) }
        log("📊 \(route.displayName): prices = \(allPrices)")
        log("✅ \(route.displayName): TWD \(Int(price)) (\(airlineName))")

        return FlightPrice(
            routeId: route.id,
            price: price,
            currency: cheapestOffer.price.currency,
            airline: airlineName,
            duration: totalDuration,
            stops: stops
        )
    }

    /// Parse ISO 8601 duration (e.g., "PT14H30M") to minutes
    private func parseDuration(_ duration: String) -> Int {
        var minutes = 0
        var currentNumber = ""

        for char in duration {
            if char.isNumber {
                currentNumber += String(char)
            } else if char == "H", let hours = Int(currentNumber) {
                minutes += hours * 60
                currentNumber = ""
            } else if char == "M", let mins = Int(currentNumber) {
                minutes += mins
                currentNumber = ""
            }
        }

        return minutes
    }

    private func log(_ message: String) {
        let logFile = "/tmp/flightpricetracker.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [Amadeus] \(message)\n"
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

    /// Fetch prices for all enabled routes
    func fetchAllPrices(routes: [FlightRoute], clientId: String, clientSecret: String) async -> [Result<FlightPrice, Error>] {
        let enabledRoutes = routes.filter { $0.isEnabled }
        var results: [Result<FlightPrice, Error>] = []
        log("Starting Amadeus fetch for \(enabledRoutes.count) routes")

        for (index, route) in enabledRoutes.enumerated() {
            // Add delay between requests to avoid rate limiting
            if index > 0 {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
            }

            do {
                let price = try await fetchFlightPrice(for: route, clientId: clientId, clientSecret: clientSecret)
                results.append(.success(price))
            } catch {
                results.append(.failure(error))
                log("❌ \(route.displayName): \(error.localizedDescription)")
            }
        }

        log("Completed Amadeus fetch")
        return results
    }
}

// MARK: - API Response Models

struct AmadeusTokenResponse: Codable {
    let type: String
    let username: String
    let applicationName: String
    let clientId: String
    let tokenType: String
    let accessToken: String
    let expiresIn: Int
    let state: String
    let scope: String

    enum CodingKeys: String, CodingKey {
        case type, username
        case applicationName = "application_name"
        case clientId = "client_id"
        case tokenType = "token_type"
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case state, scope
    }
}

struct AmadeusFlightResponse: Codable {
    let data: [AmadeusFlightOffer]
    let dictionaries: AmadeusDictionaries?
}

struct AmadeusFlightOffer: Codable {
    let id: String
    let price: AmadeusPrice
    let itineraries: [AmadeusItinerary]
}

struct AmadeusPrice: Codable {
    let currency: String
    let total: String
    let base: String?
}

struct AmadeusItinerary: Codable {
    let duration: String?
    let segments: [AmadeusSegment]
}

struct AmadeusSegment: Codable {
    let departure: AmadeusLocation
    let arrival: AmadeusLocation
    let carrierCode: String
    let number: String?
    let duration: String?
}

struct AmadeusLocation: Codable {
    let iataCode: String
    let at: String
}

struct AmadeusDictionaries: Codable {
    let carriers: [String: String]?
}

// MARK: - Errors

enum AmadeusApiError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case noFlightsFound
    case httpError(statusCode: Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationFailed:
            return "Authentication failed. Please check your Amadeus API credentials."
        case .noFlightsFound:
            return "No flights found for this route"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}
