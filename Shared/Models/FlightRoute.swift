import Foundation

/// Represents a flight route to monitor
struct FlightRoute: Codable, Identifiable, Hashable {
    let id: UUID
    var departureAirport: String
    var arrivalAirport: String
    var destinationCity: String
    var outboundDate: Date
    var returnDate: Date
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        departureAirport: String,
        arrivalAirport: String,
        destinationCity: String,
        outboundDate: Date,
        returnDate: Date,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.departureAirport = departureAirport
        self.arrivalAirport = arrivalAirport
        self.destinationCity = destinationCity
        self.outboundDate = outboundDate
        self.returnDate = returnDate
        self.isEnabled = isEnabled
    }

    /// Display name for the route
    var displayName: String {
        "\(departureAirport) → \(arrivalAirport)"
    }

    /// Generate Google Flights search URL for this route
    var googleFlightsURL: URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let outboundStr = dateFormatter.string(from: outboundDate)
        let returnStr = dateFormatter.string(from: returnDate)

        // Format: "Flights to DEST from ORIGIN on YYYY-MM-DD through YYYY-MM-DD"
        let query = "Flights to \(arrivalAirport) from \(departureAirport) on \(outboundStr) through \(returnStr)"

        // URL encode the query
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        return URL(string: "https://www.google.com/travel/flights?q=\(encodedQuery)")!
    }
}

// MARK: - Default Routes (TPE to Europe)
extension FlightRoute {
    /// Default monitored routes from Taipei
    static let defaultRoutes: [FlightRoute] = {
        // Fixed travel dates: 2026-05-18 to 2026-06-05
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let outbound = dateFormatter.date(from: "2026-05-18")!
        let returnDate = dateFormatter.date(from: "2026-06-05")!

        return [
            FlightRoute(
                departureAirport: "TPE",
                arrivalAirport: "FCO",
                destinationCity: "羅馬",
                outboundDate: outbound,
                returnDate: returnDate
            ),
            FlightRoute(
                departureAirport: "TPE",
                arrivalAirport: "CDG",
                destinationCity: "巴黎",
                outboundDate: outbound,
                returnDate: returnDate
            ),
            FlightRoute(
                departureAirport: "TPE",
                arrivalAirport: "ZRH",
                destinationCity: "蘇黎世",
                outboundDate: outbound,
                returnDate: returnDate
            ),
            FlightRoute(
                departureAirport: "TPE",
                arrivalAirport: "LHR",
                destinationCity: "倫敦",
                outboundDate: outbound,
                returnDate: returnDate
            ),
            FlightRoute(
                departureAirport: "TPE",
                arrivalAirport: "KEF",
                destinationCity: "雷克雅維克",
                outboundDate: outbound,
                returnDate: returnDate
            ),
            FlightRoute(
                departureAirport: "TPE",
                arrivalAirport: "IST",
                destinationCity: "伊斯坦堡",
                outboundDate: outbound,
                returnDate: returnDate
            ),
            FlightRoute(
                departureAirport: "TPE",
                arrivalAirport: "PRG",
                destinationCity: "布拉格",
                outboundDate: outbound,
                returnDate: returnDate
            )
        ]
    }()
}
