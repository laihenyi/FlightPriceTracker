# FlightPriceTracker

macOS 桌面小工具，追蹤台北到歐洲航線的機票價格。

## 功能特色

- 監控 7 條航線：台北 → 羅馬、巴黎、蘇黎世、倫敦、雷克雅維克、伊斯坦堡、布拉格
- 每日 8:00 / 12:00 / 16:00 / 20:00 自動查詢（每天 4 次）
- 顯示價格漲跌幅（綠色跌/紅色漲）
- 跌幅超過 5% 推送通知 🔔
- 自動排除中國航空公司（優先顯示非中國籍航班）
- Widget 支援 Small / Medium / Large 三種尺寸

## 系統需求

- macOS 13.0+
- Xcode 14.0+
- [SerpApi](https://serpapi.com/) 帳號（付費方案）

## 安裝步驟

### 1. 複製並開啟專案

```bash
# 複製專案
git clone https://github.com/laihenyi/FlightPriceTracker.git
cd FlightPriceTracker

# 用 Xcode 開啟
open FlightPriceTracker.xcodeproj
```

### 2. 設定開發者帳號

1. 選擇專案 → Signing & Capabilities
2. 選擇你的 Development Team
3. 對 FlightPriceTracker 和 FlightWidgetExtension 兩個 Target 都要設定

### 3. 建立 App Group（如需要）

如果 App Group 尚未建立：
1. 登入 [Apple Developer](https://developer.apple.com/)
2. 建立 App Group ID: `group.com.flightpricetracker`
3. 在 Xcode 中勾選該 App Group

### 4. 設定 API Key

1. 執行 App
2. 點擊右上角齒輪圖示
3. 輸入你的 SerpApi API Key
4. 點擊「儲存」

## 檔案結構

```
FlightPriceTracker/
├── Shared/                          # 共用模組
│   ├── Models/
│   │   ├── FlightRoute.swift        # 航線模型
│   │   ├── FlightPrice.swift        # 價格模型
│   │   └── PriceChange.swift        # 漲跌計算
│   ├── Services/
│   │   ├── SerpApiService.swift     # API 請求
│   │   └── NotificationService.swift # 推送通知
│   └── Storage/
│       └── DataStore.swift          # App Group 儲存
├── FlightPriceTracker/              # 主 App
│   ├── FlightPriceTrackerApp.swift
│   └── Views/
│       ├── ContentView.swift        # 主頁面
│       ├── SettingsView.swift       # 設定頁面
│       └── RouteEditorView.swift    # 航線編輯
└── FlightWidget/                    # Widget Extension
    ├── FlightWidget.swift           # Widget 主檔案
    └── FlightWidgetBundle.swift
```

## 監控航線

| 出發地 | 目的地 | 機場代碼 |
|--------|--------|----------|
| 台北 (TPE) | 羅馬 | FCO |
| 台北 (TPE) | 巴黎 | CDG |
| 台北 (TPE) | 蘇黎世 | ZRH |
| 台北 (TPE) | 倫敦 | LHR |
| 台北 (TPE) | 雷克雅維克 | KEF |
| 台北 (TPE) | 伊斯坦堡 | IST |
| 台北 (TPE) | 布拉格 | PRG |

## API 用量估算

| 項目 | 數量 |
|------|------|
| 航線數 | 7 條 |
| 每日查詢 | 4 次 (8:00, 12:00, 16:00, 20:00) |
| 每日總查詢 | 28 次 |
| 每月總查詢 | ~840 次 |

建議使用 SerpApi 付費方案以支援完整功能。

## Widget 預覽

### Medium Size
```
┌─────────────────────────────────────┐
│ ✈️ 機票價格監控      更新: 12:00    │
├─────────────────────────────────────┤
│ TPE → FCO  羅馬      $28,500  ▼-8%🔔│
│ TPE → CDG  巴黎      $25,800  ▲+3%  │
│ TPE → ZRH  蘇黎世    $32,000  ▼-2%  │
└─────────────────────────────────────┘
```

## 注意事項

- API Key 儲存在 macOS Keychain 中，安全性較高
- Widget 刷新由 macOS 系統控制，可能與設定時間略有差異
- 首次使用需授予通知權限

## License

MIT
