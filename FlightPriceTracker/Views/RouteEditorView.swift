import SwiftUI

struct RouteEditorView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    let route: FlightRoute

    @State private var departureAirport: String
    @State private var arrivalAirport: String
    @State private var destinationCity: String
    @State private var outboundDate: Date
    @State private var returnDate: Date
    @State private var isEnabled: Bool

    init(route: FlightRoute) {
        self.route = route
        _departureAirport = State(initialValue: route.departureAirport)
        _arrivalAirport = State(initialValue: route.arrivalAirport)
        _destinationCity = State(initialValue: route.destinationCity)
        _outboundDate = State(initialValue: route.outboundDate)
        _returnDate = State(initialValue: route.returnDate)
        _isEnabled = State(initialValue: route.isEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("取消") {
                    dismiss()
                }

                Spacer()

                Text("編輯航線")
                    .font(.headline)

                Spacer()

                Button("儲存") {
                    saveRoute()
                }
                .disabled(!isValid)
            }
            .padding()

            Divider()

            Form {
                // Route Section
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("出發地")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("機場代碼", text: $departureAirport)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading) {
                            Text("目的地")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("機場代碼", text: $arrivalAirport)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }

                        VStack(alignment: .leading) {
                            Text("城市名稱")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("城市", text: $destinationCity)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                    }
                } header: {
                    Text("航線資訊")
                }

                // Date Section
                Section {
                    DatePicker("去程日期", selection: $outboundDate, displayedComponents: .date)
                    DatePicker("回程日期", selection: $returnDate, displayedComponents: .date)
                } header: {
                    Text("日期")
                }

                // Status Section
                Section {
                    Toggle("啟用監控", isOn: $isEnabled)
                } header: {
                    Text("狀態")
                }

                // Price History Section
                if let history = dataStore.priceHistories[route.id], !history.prices.isEmpty {
                    Section {
                        ForEach(history.prices.suffix(5).reversed()) { price in
                            HStack {
                                Text(price.fetchedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(price.formattedPrice)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    } header: {
                        Text("近期價格記錄")
                    }
                }

                // Delete Section
                Section {
                    Button(role: .destructive, action: deleteRoute) {
                        Label("刪除此航線", systemImage: "trash")
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 450)
    }

    private var isValid: Bool {
        !departureAirport.isEmpty &&
        !arrivalAirport.isEmpty &&
        !destinationCity.isEmpty &&
        returnDate > outboundDate
    }

    private func saveRoute() {
        let updatedRoute = FlightRoute(
            id: route.id,
            departureAirport: departureAirport.uppercased(),
            arrivalAirport: arrivalAirport.uppercased(),
            destinationCity: destinationCity,
            outboundDate: outboundDate,
            returnDate: returnDate,
            isEnabled: isEnabled
        )
        dataStore.updateRoute(updatedRoute)
        dismiss()
    }

    private func deleteRoute() {
        dataStore.deleteRoute(route)
        dismiss()
    }
}

// MARK: - Common Airport Codes Reference
struct AirportCodes {
    static let common: [(code: String, name: String, city: String)] = [
        ("TPE", "桃園國際機場", "台北"),
        ("TSA", "松山機場", "台北"),
        ("FCO", "菲烏米奇諾機場", "羅馬"),
        ("CDG", "戴高樂機場", "巴黎"),
        ("ZRH", "蘇黎世機場", "蘇黎世"),
        ("LHR", "希斯洛機場", "倫敦"),
        ("KEF", "凱夫拉維克機場", "雷克雅維克"),
        ("NRT", "成田機場", "東京"),
        ("HND", "羽田機場", "東京"),
        ("ICN", "仁川機場", "首爾"),
        ("HKG", "香港國際機場", "香港"),
        ("SIN", "樟宜機場", "新加坡"),
        ("BKK", "素萬那普機場", "曼谷"),
    ]
}

#Preview {
    RouteEditorView(route: FlightRoute.defaultRoutes[0])
        .environmentObject(DataStore.shared)
}
