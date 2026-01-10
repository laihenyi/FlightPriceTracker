import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var showApiKey = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false

    // Amadeus credentials
    @State private var amadeusClientId: String = ""
    @State private var amadeusClientSecret: String = ""
    @State private var showAmadeusSecret = false
    @State private var showAmadeusSaveSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("設定")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("完成") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            Form {
                // API Provider Selection
                Section {
                    Picker("資料來源", selection: $dataStore.selectedApiProvider) {
                        ForEach(DataStore.ApiProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: dataStore.selectedApiProvider) { newValue in
                        dataStore.saveApiProvider(newValue)
                    }
                } header: {
                    Text("API 來源")
                } footer: {
                    Text(dataStore.selectedApiProvider == .serpApi
                         ? "SerpApi 使用 Google Flights 資料"
                         : "Amadeus 提供官方航空資料 (免費方案可用)")
                        .font(.caption)
                }

                // SerpApi Section (shown when SerpApi is selected)
                if dataStore.selectedApiProvider == .serpApi {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SerpApi API Key")
                                .font(.headline)

                            HStack {
                                if showApiKey {
                                    TextField("輸入 API Key", text: $apiKey)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("輸入 API Key", text: $apiKey)
                                        .textFieldStyle(.roundedBorder)
                                }

                                Button(action: { showApiKey.toggle() }) {
                                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                                }
                                .buttonStyle(.borderless)
                            }

                            HStack {
                                Button("儲存 API Key") {
                                    saveApiKey()
                                }
                                .disabled(apiKey.isEmpty || isSaving)

                                if showSaveSuccess {
                                    Label("已儲存", systemImage: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }

                                Spacer()

                                Link("取得 API Key", destination: URL(string: "https://serpapi.com/manage-api-key")!)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("SerpApi 設定")
                    }
                }

                // Amadeus Section (shown when Amadeus is selected)
                if dataStore.selectedApiProvider == .amadeus {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Amadeus API 憑證")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Client ID")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                TextField("輸入 Client ID", text: $amadeusClientId)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Client Secret")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack {
                                    if showAmadeusSecret {
                                        TextField("輸入 Client Secret", text: $amadeusClientSecret)
                                            .textFieldStyle(.roundedBorder)
                                    } else {
                                        SecureField("輸入 Client Secret", text: $amadeusClientSecret)
                                            .textFieldStyle(.roundedBorder)
                                    }

                                    Button(action: { showAmadeusSecret.toggle() }) {
                                        Image(systemName: showAmadeusSecret ? "eye.slash" : "eye")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }

                            HStack {
                                Button("儲存憑證") {
                                    saveAmadeusCredentials()
                                }
                                .disabled(amadeusClientId.isEmpty || amadeusClientSecret.isEmpty || isSaving)

                                if showAmadeusSaveSuccess {
                                    Label("已儲存", systemImage: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }

                                Spacer()

                                Link("註冊 Amadeus", destination: URL(string: "https://developers.amadeus.com/register")!)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Amadeus 設定")
                    } footer: {
                        Text("免費方案：每月 2,000 次 API 呼叫")
                            .font(.caption)
                    }
                }

                // Schedule Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("每日 12:00 自動查詢", systemImage: "clock")
                        Label("每日 18:00 自動查詢", systemImage: "clock")
                        Label("跌幅超過 5% 推送通知", systemImage: "bell")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } header: {
                    Text("排程資訊")
                }

                // About Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("監控航線")
                            Spacer()
                            Text("\(dataStore.routes.filter { $0.isEnabled }.count) / \(dataStore.routes.count)")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("API 狀態")
                            Spacer()
                            if isApiConfigured {
                                Label("已設定 (\(dataStore.selectedApiProvider.rawValue))", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Label("未設定", systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } header: {
                    Text("關於")
                }

                // Danger Zone
                Section {
                    Button(role: .destructive, action: clearApiKey) {
                        Label("清除 API Key", systemImage: "trash")
                    }
                    .disabled(!dataStore.hasApiKey)

                    Button(role: .destructive, action: clearAllData) {
                        Label("清除所有資料", systemImage: "trash.fill")
                    }
                } header: {
                    Text("危險區域")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 550)
        .onAppear {
            // Load existing SerpApi key (masked)
            if dataStore.hasApiKey {
                apiKey = "••••••••••••••••"
            }
            // Load existing Amadeus credentials (masked)
            if dataStore.hasAmadeusCredentials {
                amadeusClientId = "••••••••••••••••"
                amadeusClientSecret = "••••••••••••••••"
            }
        }
    }

    /// Check if current API provider is configured
    private var isApiConfigured: Bool {
        switch dataStore.selectedApiProvider {
        case .serpApi:
            return dataStore.hasApiKey
        case .amadeus:
            return dataStore.hasAmadeusCredentials
        }
    }

    private func saveApiKey() {
        guard !apiKey.isEmpty, apiKey != "••••••••••••••••" else { return }

        isSaving = true
        if dataStore.saveApiKey(apiKey) {
            showSaveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSaveSuccess = false
            }
        }
        isSaving = false
    }

    private func saveAmadeusCredentials() {
        guard !amadeusClientId.isEmpty, amadeusClientId != "••••••••••••••••",
              !amadeusClientSecret.isEmpty, amadeusClientSecret != "••••••••••••••••" else { return }

        isSaving = true
        let idSaved = dataStore.saveAmadeusClientId(amadeusClientId)
        let secretSaved = dataStore.saveAmadeusClientSecret(amadeusClientSecret)

        if idSaved && secretSaved {
            showAmadeusSaveSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showAmadeusSaveSuccess = false
            }
        }
        isSaving = false
    }

    private func clearApiKey() {
        dataStore.deleteApiKey()
        apiKey = ""
    }

    private func clearAllData() {
        // Clear API key
        dataStore.deleteApiKey()
        apiKey = ""

        // Reset routes to default
        dataStore.routes = FlightRoute.defaultRoutes
        dataStore.saveRoutes()

        // Clear price histories
        dataStore.priceHistories = [:]
        dataStore.savePriceHistories()
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataStore.shared)
}
