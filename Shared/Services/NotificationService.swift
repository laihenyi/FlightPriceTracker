import Foundation
import UserNotifications

/// Service for managing notifications
class NotificationService {
    static let shared = NotificationService()

    private init() {}

    /// Request notification permission
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    /// Check if notifications are authorized
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    /// Send price drop notification
    func sendPriceDropNotification(
        route: FlightRoute,
        currentPrice: Double,
        previousPrice: Double,
        changePercent: Double
    ) {
        let content = UNMutableNotificationContent()
        content.title = "機票降價提醒 🎉"

        let priceFormatter = NumberFormatter()
        priceFormatter.numberStyle = .currency
        priceFormatter.currencyCode = "TWD"
        priceFormatter.maximumFractionDigits = 0

        let formattedPrice = priceFormatter.string(from: NSNumber(value: currentPrice)) ?? "$\(Int(currentPrice))"
        let formattedPrevious = priceFormatter.string(from: NSNumber(value: previousPrice)) ?? "$\(Int(previousPrice))"

        content.body = """
        \(route.departureAirport) → \(route.arrivalAirport) (\(route.destinationCity))
        降價 \(String(format: "%.1f", abs(changePercent)))%
        \(formattedPrevious) → \(formattedPrice)
        """

        content.sound = .default
        content.categoryIdentifier = "PRICE_DROP"

        // Add route info to userInfo for handling taps
        content.userInfo = [
            "routeId": route.id.uuidString,
            "destination": route.destinationCity
        ]

        let request = UNNotificationRequest(
            identifier: "price-drop-\(route.id.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    /// Check prices and send notifications for significant drops
    func checkAndNotify(
        routes: [FlightRoute],
        currentPrices: [UUID: FlightPrice],
        previousPrices: [UUID: FlightPrice]
    ) {
        for route in routes where route.isEnabled {
            guard let current = currentPrices[route.id],
                  let previous = previousPrices[route.id] else {
                continue
            }

            let change = PriceChange(currentPrice: current.price, previousPrice: previous.price)

            if change.isSignificantDrop {
                sendPriceDropNotification(
                    route: route,
                    currentPrice: current.price,
                    previousPrice: previous.price,
                    changePercent: change.changePercent
                )
            }
        }
    }

    /// Remove all pending notifications
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Remove all delivered notifications
    func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
