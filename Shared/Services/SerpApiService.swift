import Foundation

/// Service for fetching flight prices from SerpApi
actor SerpApiService {
    static let shared = SerpApiService()

    private let baseURL = "https://serpapi.com/search.json"
    private let session: URLSession

    /// Chinese airport codes to exclude from layovers (不在中國境內轉機)
    private let chinaAirportCodes: Set<String> = [
        // Beijing 北京
        "PEK", "PKX",
        // Shanghai 上海
        "PVG", "SHA",
        // Guangzhou 廣州
        "CAN",
        // Shenzhen 深圳
        "SZX",
        // Chengdu 成都
        "CTU", "TFU",
        // Chongqing 重慶
        "CKG",
        // Xi'an 西安
        "XIY",
        // Hangzhou 杭州
        "HGH",
        // Nanjing 南京
        "NKG",
        // Wuhan 武漢
        "WUH",
        // Kunming 昆明
        "KMG",
        // Xiamen 廈門
        "XMN",
        // Qingdao 青島
        "TAO",
        // Dalian 大連
        "DLC",
        // Tianjin 天津
        "TSN",
        // Shenyang 瀋陽
        "SHE",
        // Harbin 哈爾濱
        "HRB",
        // Changsha 長沙
        "CSX",
        // Zhengzhou 鄭州
        "CGO",
        // Fuzhou 福州
        "FOC",
        // Jinan 濟南
        "TNA",
        // Urumqi 烏魯木齊
        "URC",
        // Nanning 南寧
        "NNG",
        // Haikou 海口
        "HAK",
        // Sanya 三亞
        "SYX",
        // Guiyang 貴陽
        "KWE",
        // Lanzhou 蘭州
        "LHW",
        // Yinchuan 銀川
        "INC",
        // Xining 西寧
        "XNN",
        // Hohhot 呼和浩特
        "HET",
        // Nanchang 南昌
        "KHN",
        // Hefei 合肥
        "HFE",
        // Changchun 長春
        "CGQ",
        // Shijiazhuang 石家莊
        "SJW",
        // Taiyuan 太原
        "TYN",
        // Wuxi 無錫
        "WUX",
        // Ningbo 寧波
        "NGB",
        // Wenzhou 溫州
        "WNZ",
        // Zhuhai 珠海
        "ZUH",
    ]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60  // Increased timeout
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    /// Check if a flight has any layover in China (中國境內轉機)
    private func hasLayoverInChina(_ flight: SerpApiFlight) -> Bool {
        guard let layovers = flight.layovers else { return false }
        for layover in layovers {
            if chinaAirportCodes.contains(layover.id.uppercased()) {
                return true
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
            URLQueryItem(name: "gl", value: "tw"),  // Geolocation: Taiwan
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

        let apiResponse: SerpApiResponse
        do {
            apiResponse = try JSONDecoder().decode(SerpApiResponse.self, from: data)
        } catch let DecodingError.keyNotFound(key, context) {
            log("❌ Decoding error - Key '\(key.stringValue)' not found: \(context.debugDescription)")
            throw SerpApiError.decodingError("Missing key: \(key.stringValue)")
        } catch let DecodingError.typeMismatch(type, context) {
            log("❌ Decoding error - Type mismatch for \(type): \(context.debugDescription)")
            throw SerpApiError.decodingError("Type mismatch: \(type)")
        } catch let DecodingError.valueNotFound(type, context) {
            log("❌ Decoding error - Value not found for \(type): \(context.debugDescription)")
            throw SerpApiError.decodingError("Value not found: \(type)")
        } catch {
            log("❌ Decoding error: \(error)")
            throw error
        }

        // Find the best (cheapest) flight, excluding flights with layovers in China and flights without prices
        let allFlights = (apiResponse.bestFlights ?? []) + (apiResponse.otherFlights ?? [])
        let flightsWithPrice = allFlights.filter { $0.price != nil }
        let filteredFlights = flightsWithPrice.filter { !hasLayoverInChina($0) }

        // Log diagnostic info
        log("📊 \(route.displayName): bestFlights=\(apiResponse.bestFlights?.count ?? 0), otherFlights=\(apiResponse.otherFlights?.count ?? 0)")
        if let priceInsights = apiResponse.priceInsights, let lowestPrice = priceInsights.lowestPrice {
            log("📊 \(route.displayName): priceInsights.lowestPrice=\(lowestPrice)")
        }

        // Log all available prices for debugging
        let sortedPrices = flightsWithPrice.compactMap { $0.price }.sorted()
        if !sortedPrices.isEmpty {
            log("📊 \(route.displayName): all prices in response: \(sortedPrices.prefix(5).map { String($0) }.joined(separator: ", "))")
        }

        // Log filtered prices
        let filteredPrices = filteredFlights.compactMap { $0.price }.sorted()
        if !filteredPrices.isEmpty {
            log("📊 \(route.displayName): after China filter: \(filteredPrices.prefix(5).map { String($0) }.joined(separator: ", "))")
        }

        guard let cheapestFlight = filteredFlights.min(by: { ($0.price ?? Int.max) < ($1.price ?? Int.max) }),
              let price = cheapestFlight.price else {
            // If no flights after filtering, try all flights as fallback
            guard let fallbackFlight = flightsWithPrice.min(by: { ($0.price ?? Int.max) < ($1.price ?? Int.max) }),
                  let fallbackPrice = fallbackFlight.price else {
                throw SerpApiError.noFlightsFound
            }
            // Return fallback but mark it
            return FlightPrice(
                routeId: route.id,
                price: Double(fallbackPrice),
                currency: "TWD",
                airline: (fallbackFlight.flights.first?.airline ?? "Unknown") + " ⚠️",
                duration: fallbackFlight.totalDuration,
                stops: fallbackFlight.flights.count - 1
            )
        }

        return FlightPrice(
            routeId: route.id,
            price: Double(price),
            currency: "TWD",
            airline: cheapestFlight.flights.first?.airline ?? "Unknown",
            duration: cheapestFlight.totalDuration,
            stops: cheapestFlight.flights.count - 1
        )
    }

    private func log(_ message: String) {
        let logFile = "/tmp/flightpricetracker.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [API] \(message)\n"
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

    /// Fetch prices for all enabled routes (sequential to avoid rate limiting)
    func fetchAllPrices(routes: [FlightRoute], apiKey: String) async -> [Result<FlightPrice, Error>] {
        let enabledRoutes = routes.filter { $0.isEnabled }
        var results: [Result<FlightPrice, Error>] = []
        log("Starting fetch for \(enabledRoutes.count) routes")

        for (index, route) in enabledRoutes.enumerated() {
            // Add delay between requests to avoid rate limiting (except first)
            if index > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            }

            log("Fetching \(route.displayName)...")
            do {
                let price = try await self.fetchFlightPrice(for: route, apiKey: apiKey)
                results.append(.success(price))
                log("✅ \(route.displayName): TWD \(price.price)")
            } catch {
                results.append(.failure(error))
                log("❌ \(route.displayName): \(error.localizedDescription)")
            }
        }

        log("Completed all fetches")
        return results
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
    let price: Int?  // Some flights may not have a price
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
    case decodingError(String)

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
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}
