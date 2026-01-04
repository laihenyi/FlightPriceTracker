import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var showApiKey = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false

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
                // API Key Section
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
                    Text("API 設定")
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
                            if dataStore.hasApiKey {
                                Label("已設定", systemImage: "checkmark.circle.fill")
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
        .frame(width: 450, height: 500)
        .onAppear {
            // Load existing API key (masked)
            if dataStore.hasApiKey {
                apiKey = "••••••••••••••••"
            }
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
