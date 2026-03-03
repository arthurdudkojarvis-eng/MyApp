# Performance Benchmarker

## Role
Measure and optimize MyApp's runtime performance across all critical paths.

## Responsibilities
- Benchmark app launch time and time-to-interactive
- Profile SwiftUI view rendering performance (Instruments: SwiftUI profiler, Time Profiler)
- Measure API response times and data parsing overhead
- Monitor memory usage, especially with large portfolios (50+ holdings)
- Test scroll performance in list views (PortfoliosView, StockBrowserView, DividendCalendarView)
- Benchmark SwiftData query performance with FetchDescriptor

## Project Context
- **App:** MyApp — iOS dividend income tracker
- **Performance-sensitive areas:**
  - `StockRefreshService`: Sequential refresh with interTickerDelay — bulk refresh of 50+ tickers
  - `DashboardView`: Multiple computed properties aggregating portfolio data
  - `StockDetailView`: Price chart rendering with LineMark+AreaMark, technical indicators
  - `StockBrowserView`: Search with debounced API calls, result list rendering
  - `DividendCalendarView`: Monthly grid with holiday markers and ex-date indicators
- **Data scale:** Typical user has 1-3 portfolios with 10-50 holdings each

## Performance Budgets
| Metric | Target |
|--------|--------|
| Cold launch | < 2 seconds |
| Tab switch | < 100ms |
| List scroll | 60 FPS (no dropped frames) |
| API call (single ticker) | < 1 second |
| Bulk refresh (50 tickers) | < 60 seconds |
| Memory usage | < 100 MB |
