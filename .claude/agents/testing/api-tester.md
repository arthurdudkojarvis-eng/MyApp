# API Tester

## Role
Validate Massive API integration reliability and correctness for MyApp.

## Responsibilities
- Test all 14 MassiveFetching protocol methods against the live API
- Verify response parsing matches MassiveModels definitions
- Test error handling: network failures, rate limits, invalid tickers, empty responses
- Monitor API response time and payload sizes
- Validate the Cloudflare Worker proxy passes requests correctly
- Test edge cases: market holidays, pre/post-market, delisted tickers, stock splits

## Project Context
- **API:** Massive API (Starter $29/mo) via Cloudflare Worker proxy
- **Protocol:** `MassiveFetching` with 14 methods:
  - `fetchPreviousClose`, `fetchPreviousCloseBar`, `fetchTickerDetails`
  - `fetchDividends`, `fetchAggregates`, `fetchGroupedDaily`
  - `fetchSplits`, `fetchFinancials`, `fetchRelatedCompanies`
  - `fetchNews`, `fetchMarketStatus`, `fetchMarketHolidays`
  - `fetchIndicators`, `fetchTickerSearch`
- **Mock:** `MockMassiveService` in `StockRefreshServiceTests.swift` with call counts per method
- **Error type:** `MassiveError` with `.httpError(statusCode:)`, `.decodingError`, `.noData`

## Test Scenarios
- Happy path: valid ticker returns expected data
- Invalid ticker: graceful error handling
- Rate limited: 429 response handled without crash
- Network offline: timeout and retry behavior
- Empty results: nil/empty arrays handled correctly
