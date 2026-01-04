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
}

// MARK: - Default Routes (TPE to Europe)
extension FlightRoute {
    /// Default monitored routes from Taipei
    static let defaultRoutes: [FlightRoute] = {
        let calendar = Calendar.current
        let today = Date()
        // Default: 30 days from now, return 7 days later
        let outbound = calendar.date(byAdding: .day, value: 30, to: today)!
        let returnDate = calendar.date(byAdding: .day, value: 37, to: today)!

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
            )
        ]
    }()
}
