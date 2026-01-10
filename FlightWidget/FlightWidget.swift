import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct FlightEntry: TimelineEntry {
    let date: Date
    let routes: [FlightRoute]
    let prices: [UUID: FlightPrice]
    let priceChanges: [UUID: PriceChange]
    let isPlaceholder: Bool

    init(
        date: Date,
        routes: [FlightRoute] = [],
        prices: [UUID: FlightPrice] = [:],
        priceChanges: [UUID: PriceChange] = [:],
        isPlaceholder: Bool = false
    ) {
        self.date = date
        self.routes = routes
        self.prices = prices
        self.priceChanges = priceChanges
        self.isPlaceholder = isPlaceholder
    }
}

// MARK: - Timeline Provider
struct FlightTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlightEntry {
        FlightEntry(
            date: Date(),
            routes: FlightRoute.defaultRoutes,
            isPlaceholder: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FlightEntry) -> Void) {
        let entry = createEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlightEntry>) -> Void) {
        let currentDate = Date()
        let entry = createEntry(date: currentDate)

        // Calculate next refresh time (12:00 or 18:00)
        let nextRefresh = calculateNextRefreshDate(from: currentDate)

        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func createEntry(date: Date) -> FlightEntry {
        let dataStore = DataStore.shared

        var prices: [UUID: FlightPrice] = [:]
        var priceChanges: [UUID: PriceChange] = [:]

        for route in dataStore.routes {
            if let price = dataStore.getLatestPrice(for: route.id) {
                prices[route.id] = price
            }
            if let change = dataStore.getPriceChange(for: route.id) {
                priceChanges[route.id] = change
            }
        }

        return FlightEntry(
            date: date,
            routes: dataStore.routes,
            prices: prices,
            priceChanges: priceChanges
        )
    }

    /// Refresh schedule: 8:00, 12:00, 16:00, 20:00
    private let refreshHours = [8, 12, 16, 20]

    private func calculateNextRefreshDate(from date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Find next refresh hour
        for refreshHour in refreshHours {
            if hour < refreshHour {
                return calendar.date(bySettingHour: refreshHour, minute: 0, second: 0, of: date)!
            }
        }

        // All refresh times passed today, next is 8:00 tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
        return calendar.date(bySettingHour: refreshHours[0], minute: 0, second: 0, of: tomorrow)!
    }
}

// MARK: - Widget Views

struct FlightWidgetEntryView: View {
    var entry: FlightEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let entry: FlightEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "airplane")
                    .font(.caption)
                Text("機票監控")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.secondary)

            Spacer()

            // Show first route with significant drop, or cheapest
            if let route = priorityRoute {
                Link(destination: route.googleFlightsURL) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.destinationCity)
                            .font(.headline)
                            .lineLimit(1)

                        if let price = entry.prices[route.id] {
                            Text(price.formattedPrice)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            if let change = entry.priceChanges[route.id] {
                                HStack(spacing: 2) {
                                    Text(change.arrowIndicator)
                                    Text(change.formattedChangePercent)
                                    if change.isSignificantDrop {
                                        Text("🔔")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(change.changeColor)
                            }
                        }
                    }
                }
            } else {
                Text("無資料")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var priorityRoute: FlightRoute? {
        // Prioritize routes with significant drops
        let routesWithDrops = entry.routes.filter { route in
            guard let change = entry.priceChanges[route.id] else { return false }
            return change.isSignificantDrop
        }

        if let firstDrop = routesWithDrops.first {
            return firstDrop
        }

        // Otherwise return first enabled route with price
        return entry.routes.first { route in
            route.isEnabled && entry.prices[route.id] != nil
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let entry: FlightEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                    Text("機票價格監控")
                        .fontWeight(.semibold)
                }

                Spacer()

                Text("更新: \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .font(.caption)

            Divider()

            // Route List (show up to 3)
            VStack(spacing: 6) {
                ForEach(entry.routes.filter { $0.isEnabled }.prefix(3)) { route in
                    Link(destination: route.googleFlightsURL) {
                        RouteRowView(
                            route: route,
                            price: entry.prices[route.id],
                            change: entry.priceChanges[route.id]
                        )
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let entry: FlightEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                    Text("機票價格監控")
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("更新: \(entry.date.formatted(date: .omitted, time: .shortened))")
                    Text("排程: 8/12/16/20時")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .font(.caption)

            Divider()

            // Route List (show all 5)
            VStack(spacing: 8) {
                ForEach(entry.routes.filter { $0.isEnabled }) { route in
                    Link(destination: route.googleFlightsURL) {
                        RouteRowView(
                            route: route,
                            price: entry.prices[route.id],
                            change: entry.priceChanges[route.id],
                            showDetails: true
                        )
                    }
                    if route.id != entry.routes.filter({ $0.isEnabled }).last?.id {
                        Divider()
                    }
                }
            }

            Spacer()

            // Legend
            HStack {
                Label("▼ 跌價", systemImage: "arrow.down")
                    .foregroundColor(.green)
                Label("▲ 漲價", systemImage: "arrow.up")
                    .foregroundColor(.red)
                Label("🔔 跌>5%", systemImage: "bell")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Route Row View
struct RouteRowView: View {
    let route: FlightRoute
    let price: FlightPrice?
    let change: PriceChange?
    var showDetails: Bool = false

    var body: some View {
        HStack {
            // Route Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(route.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(route.destinationCity)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if showDetails, let price = price {
                    HStack(spacing: 4) {
                        Text(price.airline)
                        Text("•")
                        Text(price.formattedDuration)
                        if price.stops > 0 {
                            Text("•")
                            Text("\(price.stops)轉")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Price
            VStack(alignment: .trailing, spacing: 2) {
                if let price = price {
                    Text(price.formattedPrice)
                        .font(.subheadline)
                        .fontWeight(.bold)

                    if let change = change {
                        HStack(spacing: 2) {
                            Text(change.arrowIndicator)
                            Text(change.formattedChangePercent)
                            if change.isSignificantDrop {
                                Text("🔔")
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(change.changeColor)
                    }
                } else {
                    Text("--")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Widget Configuration
struct FlightWidget: Widget {
    let kind: String = "FlightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlightTimelineProvider()) { entry in
            if #available(macOS 14.0, *) {
                FlightWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                FlightWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .configurationDisplayName("機票價格監控")
        .description("追蹤台北到歐洲航線的機票價格")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#if DEBUG
@available(macOS 14.0, *)
#Preview("Medium Widget", as: .systemMedium) {
    FlightWidget()
} timeline: {
    FlightEntry(
        date: Date(),
        routes: FlightRoute.defaultRoutes,
        prices: [
            FlightRoute.defaultRoutes[0].id: FlightPrice(
                routeId: FlightRoute.defaultRoutes[0].id,
                price: 28500,
                airline: "長榮航空",
                duration: 840,
                stops: 1
            ),
            FlightRoute.defaultRoutes[1].id: FlightPrice(
                routeId: FlightRoute.defaultRoutes[1].id,
                price: 25800,
                airline: "中華航空",
                duration: 780,
                stops: 1
            ),
            FlightRoute.defaultRoutes[2].id: FlightPrice(
                routeId: FlightRoute.defaultRoutes[2].id,
                price: 32000,
                airline: "瑞士航空",
                duration: 900,
                stops: 1
            )
        ],
        priceChanges: [
            FlightRoute.defaultRoutes[0].id: PriceChange(currentPrice: 28500, previousPrice: 31000),
            FlightRoute.defaultRoutes[1].id: PriceChange(currentPrice: 25800, previousPrice: 25000)
        ]
    )
}
#endif
