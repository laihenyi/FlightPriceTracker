import Foundation
import SwiftUI

/// Represents price change between two price points
struct PriceChange {
    let currentPrice: Double
    let previousPrice: Double

    init(currentPrice: Double, previousPrice: Double) {
        self.currentPrice = currentPrice
        self.previousPrice = previousPrice
    }

    /// Change percentage (negative = price dropped, positive = price increased)
    var changePercent: Double {
        guard previousPrice > 0 else { return 0 }
        return ((currentPrice - previousPrice) / previousPrice) * 100
    }

    /// Absolute change in price
    var absoluteChange: Double {
        currentPrice - previousPrice
    }

    /// Whether this is a significant drop (> 5%)
    var isSignificantDrop: Bool {
        changePercent <= -5.0
    }

    /// Whether price increased
    var isPriceIncrease: Bool {
        changePercent > 0
    }

    /// Whether price decreased
    var isPriceDecrease: Bool {
        changePercent < 0
    }

    /// Whether price is unchanged
    var isUnchanged: Bool {
        abs(changePercent) < 0.01
    }

    /// Formatted change percentage string
    var formattedChangePercent: String {
        if isUnchanged {
            return "0%"
        }
        let prefix = isPriceIncrease ? "+" : ""
        return String(format: "%@%.1f%%", prefix, changePercent)
    }

    /// Arrow indicator for price direction
    var arrowIndicator: String {
        if isUnchanged {
            return "—"
        }
        return isPriceIncrease ? "▲" : "▼"
    }

    /// Color for price change display
    var changeColor: Color {
        if isUnchanged {
            return .secondary
        }
        // Green for price drop (good), Red for price increase (bad)
        return isPriceDecrease ? .green : .red
    }

    /// Alert emoji if significant drop
    var alertEmoji: String {
        isSignificantDrop ? " 🔔" : ""
    }
}

// MARK: - Convenience initializer
extension PriceChange {
    /// Initialize from price history
    init?(from history: PriceHistory) {
        guard let current = history.latestPrice,
              let previous = history.previousPrice else {
            return nil
        }
        self.init(currentPrice: current.price, previousPrice: previous.price)
    }
}
