import Foundation

/// Service for fetching flight prices from SerpApi
actor SerpApiService {
    static let shared = SerpApiService()

    private let baseURL = "https://serpapi.com/search.json"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
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

        // Find the best (cheapest) flight
        let allFlights = (apiResponse.bestFlights ?? []) + (apiResponse.otherFlights ?? [])

        guard let cheapestFlight = allFlights.min(by: { $0.price < $1.price }) else {
            throw SerpApiError.noFlightsFound
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
