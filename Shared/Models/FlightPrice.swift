import Foundation

/// Represents a flight price record
struct FlightPrice: Codable, Identifiable {
    let id: UUID
    let routeId: UUID
    let price: Double
    let currency: String
    let airline: String
    let duration: Int  // in minutes
    let stops: Int
    let fetchedAt: Date

    init(
        id: UUID = UUID(),
        routeId: UUID,
        price: Double,
        currency: String = "TWD",
        airline: String,
        duration: Int,
        stops: Int,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.routeId = routeId
        self.price = price
        self.currency = currency
        self.airline = airline
        self.duration = duration
        self.stops = stops
        self.fetchedAt = fetchedAt
    }

    /// Formatted price string
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(Int(price))"
    }

    /// Formatted duration string
    var formattedDuration: String {
        let hours = duration / 60
        let minutes = duration % 60
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Price History
struct PriceHistory: Codable {
    let routeId: UUID
    var prices: [FlightPrice]

    init(routeId: UUID, prices: [FlightPrice] = []) {
        self.routeId = routeId
        self.prices = prices
    }

    /// Get the latest price
    var latestPrice: FlightPrice? {
        prices.max(by: { $0.fetchedAt < $1.fetchedAt })
    }

    /// Get the previous price (second most recent)
    var previousPrice: FlightPrice? {
        let sorted = prices.sorted(by: { $0.fetchedAt > $1.fetchedAt })
        return sorted.count > 1 ? sorted[1] : nil
    }

    /// Add a new price record
    mutating func addPrice(_ price: FlightPrice) {
        prices.append(price)
        // Keep only last 30 records to save space
        if prices.count > 30 {
            prices = Array(prices.suffix(30))
        }
    }
}
