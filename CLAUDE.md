# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FlightPriceTracker is a macOS desktop application that monitors flight prices from Taipei (TPE) to European destinations. It consists of a menu bar app and a widget extension that share data via App Groups.

**Architecture:**
- **Shared Module** (`Shared/`): Common code used by both app and widget
  - `Models/`: Data models (`FlightRoute`, `FlightPrice`, `PriceChange`)
  - `Services/`: API service (`SerpApiService`), notification service (`NotificationService`)
  - `Storage/`: `DataStore` - centralized state management with App Group persistence
- **Main App** (`FlightPriceTracker/`): Menu bar application with settings UI
- **Widget Extension** (`FlightWidget/`): Home screen widget with multiple sizes

**Key Design Pattern:** The app uses a shared `DataStore` singleton that persists data via UserDefaults with an App Group (`group.com.flightpricetracker`), allowing both the main app and widget extension to access the same data.

## Build Commands

```bash
# Open project in Xcode
open FlightPriceTracker.xcodeproj

# Build from command line
xcodebuild -project FlightPriceTracker.xcodeproj -scheme FlightPriceTracker -configuration Debug build

# Build for release
xcodebuild -project FlightPriceTracker.xcodeproj -scheme FlightPriceTracker -configuration Release build

# Clean build
xcodebuild -project FlightPriceTracker.xcodeproj -scheme FlightPriceTracker clean
```

**Note:** This project uses Xcode Gen (`project.yml`). Regenerate the Xcode project after modifying `project.yml`:
```bash
xcodegen generate
```

## Development Setup

1. **App Group ID**: `group.com.flightpricetracker` - must be created in Apple Developer portal and enabled in both targets' entitlements
2. **Bundle Identifiers**:
   - Main app: `com.flightpricetracker.app`
   - Widget: `com.flightpricetracker.app.widget`
3. **API Key**: Stored in macOS Keychain (service: `com.flightpricetracker.apikey`), retrieved via `DataStore.loadApiKey()`

## Key Implementation Details

### Data Flow
1. `DataStore.shared.refreshPrices()` fetches prices via `SerpApiService`
2. Results are stored in `priceHistories` dictionary keyed by route UUID
3. `PriceChange` calculates percentage change between latest and previous price
4. `NotificationService` sends notifications for drops > 5%
5. Widget reads from shared `DataStore` via App Group UserDefaults

### Widget Refresh Schedule
Widget refreshes at 8:00, 12:00, 16:00, 20:00 daily. See `FlightTimelineProvider.calculateNextRefreshDate()`.

### Chinese Airline Exclusion
`SerpApiService` filters out flights with layovers in Chinese airports. See `chinaAirportCodes` set in `SerpApiService.swift`.

### Menu Bar Only Mode
The main window is hidden on launch - the app runs primarily as a menu bar extra. See `AppDelegate.applicationDidFinishLaunching()`.

### Logging
Debug logs are written to `/tmp/flightpricetracker.log` for troubleshooting API issues.

## Route Configuration

Default routes are hardcoded in `FlightRoute.defaultRoutes` (TPE → 7 European cities). The travel dates are fixed (2026-05-19 to 2026-05-31). To add/modify routes, update this static property.
