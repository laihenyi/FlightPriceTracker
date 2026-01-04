import Foundation

/// Service for fetching flight prices from SerpApi
actor SerpApiService {
    static let shared = SerpApiService()

    private let baseURL = "https://serpapi.com/search.json"
    private let session: URLSession

    /// Chinese airlines to exclude from results
    private let excludedAirlines: Set<String> = [
        // Major Chinese carriers
        "Air China", "中國國際航空",
        "China Eastern", "中國東方航空",
        "China Southern", "中國南方航空",
        "Hainan Airlines", "海南航空",
        "Xiamen Airlines", "廈門航空",
        "Shenzhen Airlines", "深圳航空",
        "Sichuan Airlines", "四川航空",
        "Spring Airlines", "春秋航空",
        "Juneyao Airlines", "吉祥航空",
        "Shandong Airlines", "山東航空",
        "Lucky Air", "祥鵬航空",
        "Tibet Airlines", "西藏航空",
        "Okay Airways", "奧凱航空",
        "9 Air", "九元航空",
        "Beijing Capital Airlines", "首都航空",
        "Loong Air", "長龍航空",
        "Ruili Airlines", "瑞麗航空",
        "Donghai Airlines", "東海航空",
        "Urumqi Air", "烏魯木齊航空",
        "Fuzhou Airlines", "福州航空",
        "Colorful Guizhou Airlines", "多彩貴州航空",
        "Qingdao Airlines", "青島航空",
        "West Air", "西部航空",
        "Chengdu Airlines", "成都航空",
        "Kunming Airlines", "昆明航空",
        "Grand China Air", "大新華航空",
        "Hebei Airlines", "河北航空",
        "Jiangxi Air", "江西航空",
        "China United Airlines", "中國聯合航空",
        "China Express Airlines", "華夏航空",
    ]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    /// Check if a flight contains any excluded airline
    private func containsExcludedAirline(_ flight: SerpApiFlight) -> Bool {
        for leg in flight.flights {
            let airlineLower = leg.airline.lowercased()
            for excluded in excludedAirlines {
                if airlineLower.contains(excluded.lowercased()) {
                    return true
                }
            }
        }
        return false
    }

    /// Fetch flight prices for a route
    func fetchFlightPrice(for route: FlightRoute, apiKey: String) async throws -> FlightPrice {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "engine", value: "google_flights"),
            URLQueryItem(name: "departure_id", value: route.departureAirport),
            URLQueryItem(name: "arrival_id", value: route.arrivalAirport),
            URLQueryItem(name: "outbound_date", value: dateFormatter.string(from: route.outboundDate)),
            URLQueryItem(name: "return_date", value: dateFormatter.string(from: route.returnDate)),
            URLQueryItem(name: "currency", value: "TWD"),
            URLQueryItem(name: "hl", value: "zh-TW"),
            URLQueryItem(name: "type", value: "1"),  // Round trip
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        guard let url = components.url else {
            throw SerpApiError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SerpApiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw SerpApiError.invalidApiKey
            }
            if httpResponse.statusCode == 429 {
                throw SerpApiError.rateLimitExceeded
            }
            throw SerpApiError.httpError(statusCode: httpResponse.statusCode)
        }

        let apiResponse = try JSONDecoder().decode(SerpApiResponse.self, from: data)

        // Find the best (cheapest) flight, excluding Chinese airlines
        let allFlights = (apiResponse.bestFlights ?? []) + (apiResponse.otherFlights ?? [])
        let filteredFlights = allFlights.filter { !containsExcludedAirline($0) }

        guard let cheapestFlight = filteredFlights.min(by: { $0.price < $1.price }) else {
            // If no flights after filtering, try all flights as fallback
            guard let fallbackFlight = allFlights.min(by: { $0.price < $1.price }) else {
                throw SerpApiError.noFlightsFound
            }
            // Return fallback but mark it
            return FlightPrice(
                routeId: route.id,
                price: Double(fallbackFlight.price),
                currency: "TWD",
                airline: (fallbackFlight.flights.first?.airline ?? "Unknown") + " ⚠️",
                duration: fallbackFlight.totalDuration,
                stops: fallbackFlight.flights.count - 1
            )
        }

        return FlightPrice(
            routeId: route.id,
            price: Double(cheapestFlight.price),
            currency: "TWD",
            airline: cheapestFlight.flights.first?.airline ?? "Unknown",
            duration: cheapestFlight.totalDuration,
            stops: cheapestFlight.flights.count - 1
        )
    }

    /// Fetch prices for all enabled routes
    func fetchAllPrices(routes: [FlightRoute], apiKey: String) async -> [Result<FlightPrice, Error>] {
        let enabledRoutes = routes.filter { $0.isEnabled }

        return await withTaskGroup(of: (UUID, Result<FlightPrice, Error>).self) { group in
            for route in enabledRoutes {
                group.addTask {
                    do {
                        let price = try await self.fetchFlightPrice(for: route, apiKey: apiKey)
                        return (route.id, .success(price))
                    } catch {
                        return (route.id, .failure(error))
                    }
                }
            }

            var results: [(UUID, Result<FlightPrice, Error>)] = []
            for await result in group {
                results.append(result)
            }

            // Sort by route order
            let routeOrder = enabledRoutes.map { $0.id }
            return results
                .sorted { routeOrder.firstIndex(of: $0.0)! < routeOrder.firstIndex(of: $1.0)! }
                .map { $0.1 }
        }
    }
}

// MARK: - API Response Models
struct SerpApiResponse: Codable {
    let bestFlights: [SerpApiFlight]?
    let otherFlights: [SerpApiFlight]?
    let priceInsights: PriceInsights?

    enum CodingKeys: String, CodingKey {
        case bestFlights = "best_flights"
        case otherFlights = "other_flights"
        case priceInsights = "price_insights"
    }
}

struct SerpApiFlight: Codable {
    let price: Int
    let totalDuration: Int
    let flights: [FlightLeg]
    let layovers: [Layover]?

    enum CodingKeys: String, CodingKey {
        case price
        case totalDuration = "total_duration"
        case flights
        case layovers
    }
}

struct FlightLeg: Codable {
    let airline: String
    let flightNumber: String?
    let departureAirport: AirportInfo
    let arrivalAirport: AirportInfo
    let duration: Int

    enum CodingKeys: String, CodingKey {
        case airline
        case flightNumber = "flight_number"
        case departureAirport = "departure_airport"
        case arrivalAirport = "arrival_airport"
        case duration
    }
}

struct AirportInfo: Codable {
    let name: String
    let id: String
    let time: String?
}

struct Layover: Codable {
    let duration: Int
    let name: String
    let id: String
}

struct PriceInsights: Codable {
    let lowestPrice: Int?
    let typicalPriceRange: [Int]?

    enum CodingKeys: String, CodingKey {
        case lowestPrice = "lowest_price"
        case typicalPriceRange = "typical_price_range"
    }
}

// MARK: - Errors
enum SerpApiError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidApiKey
    case rateLimitExceeded
    case noFlightsFound
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidApiKey:
            return "Invalid API key. Please check your SerpApi key."
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again later."
        case .noFlightsFound:
            return "No flights found for this route"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
