import Foundation

/// Scheduler for automatic background price refreshes at 8:00, 12:00, 16:00, 20:00
/// Uses Timer since BGTaskScheduler is iOS-only
@MainActor
class BackgroundTaskScheduler: ObservableObject {
    static let shared = BackgroundTaskScheduler()

    // Refresh hours: 8:00, 12:00, 16:00, 20:00
    private let refreshHours = [8, 12, 16, 20]

    private var timer: Timer?
    @Published var nextRefreshTime: Date?

    private init() {}

    /// Start the scheduler
    func start() {
        // Stop any existing timer
        stop()

        // Update next refresh time
        updateNextRefreshTime()

        // Check every minute if it's time to refresh
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.checkAndRefresh()
            }
        }

        log("✅ Background scheduler started")
    }

    /// Stop the scheduler
    func stop() {
        timer?.invalidate()
        timer = nil
        log("🛑 Background scheduler stopped")
    }

    /// Check if it's time to refresh and perform refresh if needed
    private func checkAndRefresh() async {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        // Check if current time matches a refresh hour (at minute 0)
        if currentMinute == 0 && refreshHours.contains(currentHour) {
            log("🔄 Scheduled refresh time reached: \(currentHour):00")

            // Perform refresh
            await DataStore.shared.refreshPrices()

            // Update next refresh time
            updateNextRefreshTime()
        } else {
            // Update next refresh time every minute
            updateNextRefreshTime()
        }
    }

    /// Update the next refresh time
    private func updateNextRefreshTime() {
        nextRefreshTime = calculateNextRefreshDate()
        log("📅 Next refresh scheduled for: \(formatDate(nextRefreshTime!))")
    }

    /// Calculate next refresh date based on scheduled hours
    private func calculateNextRefreshDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)

        // Find the next scheduled hour
        for hour in refreshHours {
            if currentHour < hour {
                // Later today
                return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)!
            }
        }

        // All scheduled hours passed, next is 8:00 tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        return calendar.date(bySettingHour: refreshHours[0], minute: 0, second: 0, of: tomorrow)!
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let logFile = "/tmp/flightpricetracker.log"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] [Scheduler] \(message)\n"
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
