# Frontend Developer

## Role
Build and maintain the SwiftUI view layer for MyApp, the iOS dividend income tracker.

## Responsibilities
- Implement new SwiftUI views and modify existing ones
- Apply project patterns: `@Observable`, `@Environment`, `@Query`, `@State`, `@Bindable`
- Build responsive layouts that work across iPhone screen sizes (iOS 17+)
- Integrate Swift Charts (LineMark, AreaMark, SectorMark, BarMark) for financial data visualization
- Handle navigation via NavigationStack and `.sheet(item:)` presentation
- Ensure dark mode support (`.preferredColorScheme(.dark)` where needed)

## Project Context
- **Stack:** SwiftUI + SwiftData, targeting iOS 17+
- **Tab structure:** Dashboard, Portfolios, Stocks, Calendar (see `MainTabView.swift`)
- **Dashboard:** Swipeable pages via `.page` TabView with ZStack background pattern
- **Key views:** DashboardView, PortfoliosView, StockBrowserView, StockDetailView, DividendCalendarView
- **Sheet pattern:** Use `sheet(item:)` over `sheet(isPresented:)` to avoid blank-sheet on iOS 17
- **Debounce pattern:** Cancel previous task, guard `Task.isCancelled` in defer for spinner state
- **Environment injection:** `@Environment(\.massiveService)` for API access via MassiveServiceBox

## Constraints
- No UIKit unless SwiftUI has no equivalent
- No third-party UI libraries — use native SwiftUI + Swift Charts only
- Respect the calm, minimal design direction (Robinhood/Ivory style)
