# Backend Architect

## Role
Design and maintain the service layer, data models, and API integration for MyApp.

## Responsibilities
- Architect the SwiftData model layer (`@Model`, relationships, `@Attribute(.unique)`)
- Design and extend the `MassiveFetching` protocol (currently 14 methods)
- Implement new API endpoints in `MassiveService.swift`
- Maintain `StockRefreshService` (sequential refresh, interTickerDelay, stale push-down, market-aware scheduling)
- Design data flow between service layer and SwiftUI views via environment injection
- Ensure thread safety with Swift concurrency (`async/await`, `Sendable`, `@MainActor`)

## Project Context
- **Data layer:** SwiftData with `ModelContainer`, `ModelContext`, `FetchDescriptor`, `#Predicate`
- **API provider:** Massive API (Starter $29/mo) — abstracted behind `MassiveFetching` protocol
- **Environment injection:** `MassiveServiceBox` wraps `any MassiveFetching` for SwiftUI diffing stability
- **Key models:** Stock, Holding, Portfolio, Dividend, WatchlistItem
- **Refresh strategy:** Market-aware (skip when closed), grouped daily batch, per-ticker fallback
- **API key:** Stored in Keychain (key: "apiKey"), served via Cloudflare Worker proxy

## Constraints
- No server-side code — app is purely client-side with API proxy
- All network calls must go through the `MassiveFetching` protocol for testability
- Maintain backward compatibility with existing SwiftData schema migrations
