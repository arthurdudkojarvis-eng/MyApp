# MyApp — Product Backlog

**Stack:** SwiftUI + SwiftData + Massive API (Starter $29/mo) + Cloudflare Worker proxy
**Platform:** iOS 17+, Solo dev, Free app
**Last updated:** 2026-03-13

---

## Backlog Status Summary

| Sprint | Focus | Status |
|---|---|---|
| Sprints 6–11 | API Endpoint Expansion (STORY-022–038) | Committed `9b9fff7` — all Done |
| Sprint 12 | Calendar + Search Enhancements | Committed `479e5e5` + `12f4dc6` — all Done |
| Sprint 13 | Portfolio Intelligence | Done |
| Sprint 14 | Stock Detail: Future Value + Holding Actions | Done |
| Sprint 15 | Notifications + Quotes | Done |
| Sprint 16 | UX Polish + Unstarted Icon | Partial (STORY-013 blocked on design) |
| Sprint 17 | Schwab Portfolio Import (OAuth + one-time import) | 🆕 New |
| Sprint 18 | Stock Intelligence (Screener, Signal Scores, AI Reports, Risk Analysis) | 🆕 New |

---

## Sprint 12 — Calendar + Search (P0/P1 bugs and high-value enhancements)

| ID | Story | Type | Priority | Size | Status |
|---|---|---|---|---|---|
| STORY-039 | Fix: Dividend Calendar — dates not opening on tap | Bug | P0 | S | ✅ Done |
| STORY-040 | Fix: Crypto search returns no results | Bug | P1 | S | ✅ Done |
| STORY-041 | Calendar: Show dividend amount next to pay date | Enhancement | P1 | S | ✅ Done |
| STORY-042 | Calendar: Month summary icon — stocks paying this month | Feature | P1 | M | ✅ Done |
| STORY-043 | Stock Search: Sector / yield / market-cap filters | Feature | P2 | L | ✅ Done |

**Sprint goal:** Fix two user-reported bugs. Enrich the calendar with inline payment amounts and a monthly summary entry point. Add power-user search filters.

---

## Sprint 13 — Portfolio Intelligence

| ID | Story | Type | Priority | Size | Status |
|---|---|---|---|---|---|
| STORY-044 | Portfolio: Auto-select active portfolio | Enhancement | P1 | S | ✅ Done |
| STORY-045 | Portfolio: Built-in dividend strategies (Dogs of the Dow, All Weather, etc.) | Feature | P2 | XL | ✅ Done (browse/preview only) |
| STORY-046 | Portfolio: View dividends received by month/year | Feature | P2 | M | ✅ Done |

**Sprint goal:** Make portfolio management smarter. Auto-selection removes friction. Strategy templates give beginners a starting point. The month/year income history view closes the feedback loop on actual received income.

---

## Sprint 14 — Holding Actions + Future Value Calculator

| ID | Story | Type | Priority | Size | Status |
|---|---|---|---|---|---|
| STORY-047 | Holding: Three-dot context menu on holding row | Enhancement | P1 | S | ✅ Done |
| STORY-048 | Holding: Future Value modal (dual-chart with/without DRIP) | Feature | P2 | L | ✅ Done |

**Sprint goal:** Give users a per-holding projection tool. The dual-chart view shows compounding impact of reinvestment in a compelling, visual way.

---

## Sprint 15 — Notifications + Investing Quotes

| ID | Story | Type | Priority | Size | Status |
|---|---|---|---|---|---|
| STORY-049 | Notifications: Include an investing quote + author photo | Feature | P3 | M | ✅ Done (quotes only, no author photos) |

**Sprint goal:** Make push notifications more engaging with curated quotes. Low priority — notifications already work; this is purely additive.

---

## Sprint 16 — UX Polish

| ID | Story | Type | Priority | Size | Status |
|---|---|---|---|---|---|
| STORY-013 | App Icon & Launch Screen | Feature | P1 | M | 🆕 New (blocked on design asset) |
| STORY-050 | Settings: Colored/themed fonts | Enhancement | P3 | S | ✅ Done |

**Sprint goal:** Ship the long-overdue app icon. Coloured font theming is low-priority cosmetic work that can run in parallel.

---

---

## Story Details — Sprint 12

---

### STORY-039: Fix — Dividend Calendar Dates Not Opening on Tap

**Status:** 🆕 New
**Priority:** P0
**Size:** S
**Type:** Bug
**Story:** As a user, I want to tap any calendar date that has a dividend event and see the payment details so that I can review what I am owed on that day.

**Root cause hypothesis:** In `DividendCalendarView`, `CalendarDayCell` has `.disabled(events.isEmpty && holiday == nil)`. If `rebuildEvents()` is not being called or `eventsByDay` is not populating correctly, taps will appear to do nothing. The `DividendDaySheet` is gated on `!dayEvents.isEmpty` in the `onDayTap` closure — so if events exist but the day key lookup misses (e.g. time-zone mismatch in `cal.startOfDay`), the tap is swallowed silently.

**Acceptance Criteria:**
- [ ] Tapping any day cell that has a dividend event reliably opens `DividendDaySheet`
- [ ] Debug: add a temporary `print` in `onDayTap` to confirm whether `dayEvents` is empty or populated — remove before shipping
- [ ] Confirm `cal.startOfDay(for: schedule.payDate)` and `cal.startOfDay(for: date)` use the same `Calendar.current` instance (no time-zone drift)
- [ ] `DividendDaySheet` displays correctly for all event statuses (estimated, declared, paid)
- [ ] No regression: days with no events still show nothing on tap (button disabled)

**Files to inspect/modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Calendar/DividendCalendarView.swift`

**Dependencies:** None

---

### STORY-040: Fix — Crypto Search Returns No Results

**Status:** 🆕 New
**Priority:** P1
**Size:** S
**Type:** Bug
**Story:** As a user, I want to search for cryptocurrencies by name or ticker so that I can look up prices and details for crypto assets.

**Root cause analysis:** `CryptoBrowserView` calls `fetchTickerSearch(query:, market: "crypto")`. The Massive API (Polygon.io) Starter plan does support the `crypto` market parameter on `/v3/reference/tickers`. However, crypto tickers on Polygon use an `X:` prefix (e.g. `X:BTCUSD`) and may require `locale: global` rather than the default. The `fetchTickerSearch` implementation uses two parallel calls: `ticker.gte`/`ticker.lt` prefix match and a `search` param call — both pass `market: "crypto"`. The prefix match uses `ticker.gte=BTC` which will NOT match `X:BTCUSD`. This is the likely failure: the deduped merged result is empty because neither query returns results for standard crypto ticker formats.

**Acceptance Criteria:**
- [ ] Searching "BTC" or "Bitcoin" returns at least BTC/USD in the results list
- [ ] Searching "ETH" or "Ethereum" returns ETH/USD
- [ ] Result rows display the crypto ticker and name correctly
- [ ] The search result rows do not show a stock exchange (crypto has no `primaryExchange`)
- [ ] If the Massive API Starter tier genuinely does not support crypto search (confirmed by 403/empty results on the `crypto` market), the Crypto tab displays a clear "Crypto search is not available on the current API plan" message rather than a broken search experience

**Implementation notes:**
- Crypto tickers on Polygon use `X:BTCUSD` format. The `ticker.gte` prefix filter needs to use `X:` prefix or be omitted for crypto — only the `search` param query is reliable.
- Consider adding a crypto-specific variant of `fetchTickerSearch` that skips the prefix-match leg and relies only on `search=query`.
- Alternatively: if Massive API Starter truly has no crypto data, gate the Crypto tab with a `ContentUnavailableView` explaining the limitation.

**Files to modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Services/Massive/MassiveService.swift`
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Crypto/CryptoBrowserView.swift`

**Dependencies:** None

**Flag:** Needs API tier verification. Test against live Massive API with `market=crypto` before assuming it is a code bug. If the plan does not support crypto, this becomes a UX-only fix (graceful degradation message).

---

### STORY-041: Calendar — Show Dividend Amount Next to Pay Date

**Status:** 🆕 New
**Priority:** P1
**Size:** S
**Type:** Enhancement
**Story:** As a user viewing the calendar, I want to see the total dividend amount I will receive next to each pay date so that I can understand my cash flow at a glance without tapping into each day.

**Acceptance Criteria:**
- [ ] Each `CalendarDayCell` that has events shows the summed `totalAmount` below the date number (below the dot indicator)
- [ ] Amount is formatted as currency: "$12.50" — use `.formatted(.currency(code: "USD"))` with `.compact` style for amounts >= $1,000 (e.g. "$1.2K")
- [ ] Text uses `caption2` font, `.secondary` foreground style
- [ ] Amount is only shown when there is at least one event on that day
- [ ] Cell height adjusts to accommodate the extra line — remove the fixed `frame(height: 46)` constraint or increase to 58 pt
- [ ] Accessibility: `accessibilityLabel` on the cell includes the total amount ("3 dividends, $47.20")
- [ ] No layout breakage on the smallest supported device (iPhone SE 3rd gen, 375pt wide)

**Files to modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Calendar/DividendCalendarView.swift`

**Dependencies:** None (totalAmount already computed in `CalendarDividendEvent`)

---

### STORY-042: Calendar — Month Summary Icon (Stocks Paying This Month)

**Status:** 🆕 New
**Priority:** P1
**Size:** M
**Type:** Feature
**Story:** As a user, I want to tap an icon next to each month name in the calendar and see a list of all stocks paying dividends that month (with their logos and amounts) so that I can get a quick income overview without scrolling day by day.

**Acceptance Criteria:**
- [ ] In `MonthGridView`, an info/list icon button (`list.bullet` or `chart.bar.doc.horizontal`) appears trailing the month name label
- [ ] Tapping the icon opens a sheet showing all dividend events for that month, grouped by ticker
- [ ] Each row in the sheet shows: stock ticker, company name, pay date, per-share amount, and total amount for the user's holdings
- [ ] Rows include a logo/icon using `AsyncImage` from the ticker's `MassiveTickerDetails.branding.iconUrl` — show a placeholder `Circle` while loading
- [ ] Logo fetch is best-effort: if `iconUrl` is nil or fails, show the ticker initial in a colored circle (same pattern used in other views)
- [ ] Sheet header shows "Month Total: $XXX.XX" summing all events in the month
- [ ] Sheet uses `.presentationDetents([.medium, .large])` and `.presentationDragIndicator(.visible)`
- [ ] If there are no events for the month, the icon is hidden (not shown for empty months)

**Files to modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Calendar/DividendCalendarView.swift`

**Dependencies:** STORY-041 (coordinate layout changes to MonthGridView)

**Note:** Logo fetch requires calling `fetchImageData(from:)` or `fetchTickerDetails(ticker:)` per ticker to get `iconUrl`. Cache results in a `[String: URL?]` dictionary on the sheet view to avoid redundant fetches. Do NOT call ticker details on every month scroll — only when the sheet is opened.

---

### STORY-043: Stock Search — Sector / Yield / Market-Cap Filters

**Status:** 🆕 New
**Priority:** P2
**Size:** L
**Type:** Feature
**Story:** As a user searching for stocks, I want to filter results by sector, dividend yield range, and market capitalization so that I can discover stocks that fit my specific investment criteria quickly.

**Acceptance Criteria:**
- [ ] A "Filter" button (funnel icon) appears in the `StockBrowserView` toolbar
- [ ] Tapping opens a filter sheet with three sections: Sector, Dividend Yield, Market Cap
- [ ] Sector: a multi-select list of common sectors (Technology, Financials, Healthcare, Energy, Utilities, Consumer Staples, Real Estate, Industrials, Materials, Communication, Consumer Discretionary)
- [ ] Dividend Yield: a **circular/arc slider** (custom component) where dragging selects a minimum yield percentage from 0% to 15%; value displayed in the center of the arc
- [ ] Market Cap: a segmented picker with options: Any / Small (<$2B) / Mid ($2B–$10B) / Large (>$10B)
- [ ] Applied filters are shown as dismissible chips below the search bar
- [ ] Filters are applied client-side against the current search results (not as additional API query params) — this avoids API complexity and works within Massive Starter plan limits
- [ ] Clearing all filters returns to unfiltered results
- [ ] Filter state persists during the session (cleared on app relaunch)
- [ ] Accessible: all filter controls have `accessibilityLabel`

**Implementation notes — Circular Slider:**
- The circular slider is a custom `Shape`-based SwiftUI view using `DragGesture` to map drag position to a percentage value
- Draw an arc (`Path` with `addArc`) as the track; draw a filled arc segment for the selected range; place a draggable knob `Circle` at the arc endpoint
- Use `atan2` to convert drag coordinates to angle, then normalize to 0–15% range
- Cap at a sensible 270-degree sweep arc, leaving a gap at the bottom (standard circular slider convention)

**Files to modify/create:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Stocks/StockBrowserView.swift`
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Stocks/StockSearchFilterView.swift` (new)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/UI/CircularSlider.swift` (new)

**Dependencies:** None

**Note:** The yield and sector data used for filtering comes from `MassiveTickerDetails` (fetched on detail view open) and is not part of the search result struct. Filtering on yield/sector client-side means it only filters what is already on screen. This is an acceptable MVP trade-off. A future iteration could pre-fetch details for all results — flag as a follow-on.

---

---

## Story Details — Sprint 13

---

### STORY-044: Portfolio — Auto-Select Active Portfolio

**Status:** 🆕 New
**Priority:** P1
**Size:** S
**Type:** Enhancement
**Story:** As a user with multiple portfolios, I want the app to automatically remember and highlight my most recently viewed portfolio so that I do not have to re-select it every time I navigate to the Portfolios tab.

**Acceptance Criteria:**
- [ ] `PortfoliosView` tracks a `@AppStorage("lastActivePortfolioID")` UUID
- [ ] The most recently selected portfolio is visually differentiated (a checkmark or accent border on its card)
- [ ] When the Portfolios tab opens and there is only one portfolio, it is automatically set as active without any user tap
- [ ] The active portfolio ID is used by `DashboardView` metrics when computing "current portfolio" values (rather than summing all portfolios indiscriminately — clarify desired behavior with user before implementing)
- [ ] Changing the active portfolio via the portfolio list updates `@AppStorage` immediately

**Files to modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/PortfoliosView.swift`
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Dashboard/DashboardView.swift` (if dashboard scoping is confirmed)

**Dependencies:** None

**Open question for user:** Should the Dashboard compute metrics for the active portfolio only, or always show all portfolios combined? This is a scope-defining decision.

---

### STORY-045: Portfolio — Built-in Dividend Strategies

**Status:** 🆕 New
**Priority:** P2
**Size:** XL
**Type:** Feature
**Story:** As a new investor, I want to browse pre-built portfolio strategies (Dogs of the Dow, All Weather, etc.) and add them to my portfolio as a starting point so that I can begin dividend investing without having to research individual stocks from scratch.

**Acceptance Criteria:**
- [ ] A "Strategies" button or tab section appears in `PortfoliosView`
- [ ] At least 3 strategies are available at launch: Dogs of the Dow (10 stocks), All Weather Portfolio (Ray Dalio, ETF-based allocation), and a High Dividend Yield basket (e.g. top-10 S&P dividend aristocrats)
- [ ] Each strategy shows: name, description, expected yield range, risk profile label, and a list of constituent tickers with target allocation percentages
- [ ] User can preview the strategy in a detail view before adding
- [ ] "Add to Portfolio" button creates holdings for each constituent ticker based on a user-supplied total investment amount and the target allocation percentages
- [ ] Strategy constituent data is hardcoded (not fetched from an API) — strategies are updated manually per app release
- [ ] Live prices for constituent tickers are fetched from Massive API to display current yield and value at the time of preview
- [ ] If a constituent ticker fails to resolve, it is shown with a warning but does not block adding the others

**Files to create/modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/PortfolioStrategiesView.swift` (new)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Data/PortfolioStrategies.swift` (new — static data)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/PortfoliosView.swift`

**Dependencies:** STORY-044 (needs active portfolio concept to know where to add holdings)

**Flag:** XL sizing because this involves: static strategy data design, a new strategy browse/detail screen, live price fetching for multiple tickers, and the "add to portfolio" flow including share calculation from a dollar amount. De-scope to M by shipping only the browse + detail screens first, deferring "Add to Portfolio" to a follow-on story. Recommend splitting.

---

### STORY-046: Portfolio — View Dividends Received by Month/Year

**Status:** 🆕 New
**Priority:** P2
**Size:** M
**Type:** Feature
**Story:** As a user, I want to view my dividend income history grouped by month and year so that I can track my actual received income over time and see if I am on target with my goals.

**Acceptance Criteria:**
- [ ] A new "Income History" view is accessible from the Portfolios tab (e.g. a navigation link in the portfolio detail or a swipe action on the portfolio card)
- [ ] Dividends with `status == .paid` are grouped by pay-date month, displayed in a reverse-chronological list
- [ ] Each month group shows: month label, total received, and expandable rows per ticker
- [ ] A bar chart at the top (Swift Charts `BarMark`) shows the last 12 months of received income
- [ ] Months with no received dividends are shown as $0 bars (not omitted) to show gaps clearly
- [ ] If no dividends have `status == .paid`, a `ContentUnavailableView` explains that received history appears here after dividends are marked as paid
- [ ] User can switch between "By Month" and "By Year" using a `Picker` (segmented)

**Files to create/modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/DividendIncomeHistoryView.swift` (new)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/PortfoliosView.swift`

**Dependencies:** None (uses existing `DividendSchedule` SwiftData model with `status == .paid`)

---

---

## Story Details — Sprint 14

---

### STORY-047: Holding — Three-Dot Context Menu

**Status:** 🆕 New
**Priority:** P1
**Size:** S
**Type:** Enhancement
**Story:** As a user viewing holdings in a portfolio, I want a three-dot context menu on each holding row so that I can quickly access actions like Edit, Delete, and Future Value without navigating away.

**Acceptance Criteria:**
- [ ] Each holding row in `PortfolioHoldingsView` has a trailing three-dot button (`ellipsis.circle` system image)
- [ ] Tapping the button opens a confirmation action sheet or menu with: "Edit Holding", "Future Value", "Delete"
- [ ] "Edit Holding" opens the existing `EditHoldingView` (or equivalent) — no regression to existing edit flow
- [ ] "Future Value" opens the `HoldingFutureValueView` modal defined in STORY-048
- [ ] "Delete" triggers the existing delete confirmation — no change to delete logic
- [ ] The three-dot button is accessible: `accessibilityLabel("More options for \(ticker)")`

**Files to modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/PortfoliosView.swift`

**Dependencies:** STORY-048 (the Future Value action needs STORY-048 to exist)

---

### STORY-048: Holding — Future Value Modal (Dual-Chart DRIP Projection)

**Status:** 🆕 New
**Priority:** P2
**Size:** L
**Type:** Feature
**Story:** As a user who has added a stock to their portfolio, I want to see a Future Value projection modal showing how my invested amount grows over time — with and without dividend reinvestment — so that I can understand the long-term compounding impact of DRIP on a per-holding basis.

**Acceptance Criteria:**
- [ ] `HoldingFutureValueView` is a modal sheet presenting two Swift Charts overlaid or stacked: one `AreaMark`/`LineMark` for growth without reinvestment, one for growth with full DRIP
- [ ] Controls (matching DRIPSimulatorView style): a `Toggle` (radio-style) for "Reinvest Dividends" and a `Slider` for years (1–40, step 1), with Stepper for precise adjustment
- [ ] Inputs pre-populated from the holding: initial value = `holding.shares × holding.averageCostBasis`, annual yield derived from the stock's dividend schedule
- [ ] "Without DRIP" line: initial value grows at a user-adjustable stock appreciation rate (default 7% p.a.) — add a secondary `Slider` for appreciation rate (0%–15%)
- [ ] "With DRIP" line: same appreciation + dividends reinvested at the same yield
- [ ] Both projections displayed simultaneously on a single chart using different colors (accent color vs. secondary) with a legend
- [ ] Final values displayed as summary cards below the chart: "Without DRIP: $X", "With DRIP: $Y", "DRIP Advantage: $Z"
- [ ] Sheet uses `.presentationDetents([.large])`, `.presentationDragIndicator(.visible)`
- [ ] Accessible: chart has `accessibilityLabel` summarizing the projection

**Implementation note:** This partially overlaps with `DRIPSimulatorView` (dashboard feature) which operates at the whole-portfolio level. This story is per-holding and adds the dual-chart + appreciation rate slider. Do NOT merge with DRIPSimulatorView — keep them separate. The holding-level view is more actionable for purchase decisions.

**Files to create/modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/HoldingFutureValueView.swift` (new)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/PortfoliosView.swift` (wire up from STORY-047 context menu)

**Dependencies:** STORY-047

---

---

## Story Details — Sprint 15

---

### STORY-049: Notifications — Investing Quote + Author Photo

**Status:** 🆕 New
**Priority:** P3
**Size:** M
**Type:** Feature
**Story:** As a user who receives dividend payment notifications, I want the notification to include an inspiring investing quote and an image of the person who said it so that the notification feels motivating rather than purely transactional.

**Acceptance Criteria:**
- [ ] A curated list of at least 20 investing quotes with attribution (author name and a bundled author photo) is added as a Swift file in the app bundle — no network fetch required
- [ ] When scheduling a dividend notification in `AlertsView`, a random quote is selected and attached to the notification content
- [ ] `UNNotificationContent.subtitle` or `.body` includes the quote text and author name (within iOS's 300-character notification body limit)
- [ ] An author photo is attached as a `UNNotificationAttachment` — images must be bundled in the app (cannot reference remote URLs in notification attachments without a notification service extension)
- [ ] If the attachment fails to load, the notification still fires without an image — no crash, no missed notification
- [ ] Author photos are provided as small PNG assets bundled in `Assets.xcassets` or a dedicated folder — max 10 images (iOS notification thumbnail is ~50pt × 50pt, so small file sizes)
- [ ] Existing notification scheduling logic in `AlertsView` is not broken

**Files to modify/create:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Alerts/AlertsView.swift`
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Data/InvestingQuotes.swift` (new — static data)
- `MyApp/Assets.xcassets` (new image assets)

**Dependencies:** None

**Flag:** iOS notification attachments using `UNNotificationAttachment` require the image file to exist on disk (not in Assets.xcassets — it must be copied to a temp file). The implementation must write the bundled image to a temp directory and pass that URL to `UNNotificationAttachment(identifier:url:options:)`. This is a non-obvious iOS platform constraint — flag for `ios-reviewer`.

---

---

## Story Details — Sprint 16

---

### STORY-013: App Icon & Launch Screen

**Status:** 🆕 New
**Priority:** P1
**Size:** M
**Type:** Feature
**Story:** As a user, I want a polished app icon and launch screen so that MyApp looks professional on my home screen and during startup.

**Acceptance Criteria:**
- [ ] A custom app icon is created at all required sizes (1024×1024 source, let Xcode generate all scales)
- [ ] Icon reflects the app's dividend/income theme (e.g. a dollar sign, upward chart, or leaf motif)
- [ ] Launch screen (LaunchScreen.storyboard or Info.plist `UILaunchScreen`) shows the app name or logo centered on a background matching the app's primary color
- [ ] No default "white box" icon appears on any device
- [ ] Icon tested on both light and dark home screen wallpapers

**Files to modify:**
- `MyApp/Assets.xcassets/AppIcon.appiconset/`
- `MyApp/Base.lproj/LaunchScreen.storyboard` or `Info.plist`

**Dependencies:** None

**Note:** Design asset (the icon artwork) must be provided by the developer. The engineering story is: slot the asset into the project and verify Xcode generates all required sizes. This is blocked until the icon design is ready.

---

### STORY-050: Settings — Colored/Themed Fonts

**Status:** 🆕 New
**Priority:** P3
**Size:** S
**Type:** Enhancement
**Story:** As a user, I want to choose a font color theme in Settings so that I can personalize the app's appearance beyond light/dark mode.

**Acceptance Criteria:**
- [ ] A "Font Theme" picker is added to the Appearance section of `SettingsView`, alongside the existing Color Scheme picker
- [ ] At least 4 theme options: Default (system), Teal, Gold, Rose — each defines an accent/text color
- [ ] Selected theme persists via `@AppStorage` in `SettingsStore`
- [ ] The selected color is applied as a custom `.accentColor` environment modifier at the app root level OR as a custom `EnvironmentKey` that views read for their primary text color
- [ ] Theme changes take effect immediately without restart
- [ ] If "Default" is selected, no color override is applied — the system accent color is used

**Implementation note:** SwiftUI `.accentColor` applies broadly. Prefer a narrow custom environment key (`\.appAccentColor: Color`) injected at root, so only explicitly styled views are affected. This prevents unintended color bleed into system controls (pickers, toggles, etc.).

**Files to modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Settings/SettingsView.swift`
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Stores/SettingsStore.swift` (add `fontTheme` property)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/App/MainTabView.swift` (inject custom accent at root)

**Dependencies:** None

---

---

## Dependency Map — New Stories

```
STORY-039 (Calendar tap bug)         — no deps
STORY-040 (Crypto search bug)        — no deps
STORY-041 (Calendar amounts)         — no deps
STORY-042 (Month summary icon)       — depends on STORY-041 (shared layout changes)
STORY-043 (Search filters)           — no deps
STORY-044 (Auto portfolio select)    — no deps
STORY-045 (Strategies)               — depends on STORY-044
STORY-046 (Income history)           — no deps
STORY-047 (Three-dot context menu)   — no deps (STORY-048 can ship later)
STORY-048 (Future Value modal)       — depends on STORY-047
STORY-049 (Quotes in notifs)         — no deps
STORY-013 (App icon)                 — blocked on design asset
STORY-050 (Colored fonts)            — no deps
```

---

## Items Flagged for Clarification or Feasibility Review

| Item | Flag | Decision Needed |
|---|---|---|
| STORY-040 (Crypto search) | Massive API Starter may not support `market=crypto` — requires live API test before scoping fix vs. graceful degradation | Developer to test manually against live Massive API with `?market=crypto` |
| STORY-043 (Circular yield slider) | Custom circular slider is non-trivial SwiftUI work (DragGesture + atan2 math). Consider shipping a standard `Slider` first and upgrading the UX in a follow-on. | Developer to decide: ship standard Slider in MVP or build circular slider from the start |
| STORY-044 (Auto portfolio select) | It is ambiguous whether Dashboard should show active portfolio only or all combined. Implementing the wrong behavior requires a refactor. | Developer must confirm scope before STORY-044 starts |
| STORY-045 (Strategies) | XL — recommend splitting into STORY-045a (browse/preview strategies, static data) and STORY-045b (Add to Portfolio action). XL as a single story is too large for a solo sprint. | Developer to confirm split |
| STORY-048 (Future Value modal) | Overlaps with existing `DRIPSimulatorView`. Confirm intent: per-holding modal (this story) is kept separate from portfolio-level dashboard DRIP view. | Confirmed in story — but worth a final developer sign-off |
| STORY-049 (Author photos in notifs) | Notification attachments require writing bundled assets to disk (temp file) — not a straightforward `AsyncImage`. Also, 20 author photos add binary size to the app. | Developer to confirm they will provide the author photo assets and accept the app size increase |
| STORY-013 (App icon) | Blocked on design. Engineering story is trivial once art exists. | Developer must create or commission icon artwork |

---

---

## Sprint 17 — Schwab Portfolio Import

**Sprint goal:** Allow the user to log in to their Charles Schwab brokerage account via OAuth and perform a one-time import of real positions into an existing Portfolio. No live sync. No token storage beyond the import session.

| ID | Story | Type | Priority | Size | Status |
|---|---|---|---|---|---|
| STORY-051 | Schwab OAuth login flow (ASWebAuthenticationSession) | Feature | P1 | M | 🆕 New |
| STORY-052 | Schwab token exchange via Cloudflare Worker | Feature | P1 | M | 🆕 New |
| STORY-053 | Schwab positions fetch + import preview screen | Feature | P1 | L | 🆕 New |
| STORY-054 | Import confirmation: create Holdings in SwiftData | Feature | P1 | M | 🆕 New |
| STORY-055 | Settings: Schwab app credentials entry (app key + secret) | Feature | P1 | S | 🆕 New |

**Dependency order:** STORY-055 → STORY-051 → STORY-052 → STORY-053 → STORY-054

---

## Story Details — Sprint 17

---

### STORY-051: Schwab OAuth Login Flow

**Status:** 🆕 New
**Priority:** P1
**Size:** M
**Type:** Feature
**Story:** As a user, I want to tap "Import from Schwab" and be taken through a secure login flow so that I can authorize the app to read my Schwab positions without sharing my password with the app.

**Acceptance Criteria:**
- [ ] A "Import from Schwab" button exists in `PortfoliosView` toolbar (or within a portfolio's detail view — see open question below)
- [ ] Tapping the button opens Schwab's OAuth authorization URL in `ASWebAuthenticationSession` (not `SFSafariViewController` — the session-based API handles the callback URL automatically)
- [ ] The authorization URL is: `https://api.schwabapi.com/v1/oauth/authorize?response_type=code&client_id={APP_KEY}&redirect_uri={REDIRECT_URI}&scope=readonly`
- [ ] The redirect URI scheme is a custom URL scheme registered in `Info.plist` (e.g. `myapp://schwab/callback`) — this scheme is also registered in the Schwab developer portal
- [ ] On successful authorization, `ASWebAuthenticationSession` delivers the full callback URL including `?code=...`
- [ ] The auth code is extracted from the callback URL query parameters and passed to STORY-052
- [ ] On user cancellation (taps "Cancel" in the browser), the flow is dismissed cleanly with no error alert shown
- [ ] On OAuth error callback (e.g. `?error=access_denied`), an alert is shown: "Schwab authorization was denied. You can try again from Settings."
- [ ] The `ASWebAuthenticationSession` is stored as a `@State` property to prevent early deallocation
- [ ] `prefersEphemeralWebBrowserSession: true` is set so the login sheet shows a fresh browser session (no stored Schwab session cookies leak in)

**Implementation notes:**
- `ASWebAuthenticationSession` requires a `presentationContextProvider` — use a UIWindowScene anchor via a helper struct conforming to `ASWebAuthenticationPresentationContextProviding`
- Redirect URI must exactly match what is registered in the Schwab developer portal. Use `myapp://schwab/callback` as the default — can be changed in STORY-055 if the dev uses a different scheme
- Do NOT use `openURL` environment action — it opens Safari and cannot receive the callback URL

**Files to create/modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/SchwabImportView.swift` (new — hosts the full import flow as a sheet)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Services/Schwab/SchwabOAuthService.swift` (new)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/PortfoliosView.swift` (add Import button)
- `MyApp/Info.plist` (register `myapp` URL scheme)

**Dependencies:** STORY-055 (app key must be stored in Keychain before OAuth URL can be built)

**Open question:** Should "Import from Schwab" live in the Portfolios list toolbar, or inside a specific Portfolio's holdings view (i.e. user picks the target portfolio first, then imports)? Recommendation: import from within `PortfolioHoldingsView` — that way the target portfolio is unambiguous. Needs developer confirmation.

---

### STORY-052: Schwab Token Exchange via Cloudflare Worker

**Status:** 🆕 New
**Priority:** P1
**Size:** M
**Type:** Feature
**Story:** As a developer, I want the OAuth authorization code to be exchanged for an access token via the existing Cloudflare Worker proxy so that the Schwab app secret never lives inside the iOS binary.

**Acceptance Criteria:**
- [ ] A new route is added to the Cloudflare Worker (`POST /schwab/token`) that accepts `{ code, redirect_uri }` in the request body and calls the Schwab token endpoint on behalf of the app
- [ ] The worker holds `SCHWAB_APP_KEY` and `SCHWAB_APP_SECRET` as Wrangler secrets (never in the iOS binary or source code)
- [ ] The worker constructs the Basic Auth header (`base64(app_key:app_secret)`) and calls `POST https://api.schwabapi.com/v1/oauth/token` with `grant_type=authorization_code`
- [ ] On success, the worker returns `{ access_token, refresh_token, expires_in }` to the iOS app
- [ ] The worker does NOT log or store tokens
- [ ] The iOS `SchwabOAuthService` calls `POST {workerBaseURL}/schwab/token` with the `X-App-Token` header (existing auth pattern)
- [ ] On HTTP error from Schwab, the worker returns the upstream status code and error body to iOS unchanged
- [ ] The iOS client surfaces a user-readable error on failure: "Could not connect to Schwab. Please try again."
- [ ] The access token and refresh token are held in memory only (NOT written to Keychain or UserDefaults) — they exist only for the duration of the import session. After import completes or the sheet is dismissed, they are discarded.

**Implementation notes:**
- The existing worker only handles GET. This route requires POST with a JSON body — add a `POST` method check branch
- Schwab token endpoint requires `Content-Type: application/x-www-form-urlencoded` for the upstream request, but the iOS → worker leg can use JSON for simplicity
- The worker must NOT forward the `X-App-Token` header to Schwab's servers

**Files to create/modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/worker/src/index.ts` (add `/schwab/token` POST route)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Services/Schwab/SchwabOAuthService.swift` (add `exchangeCode(code:redirectURI:)` method)

**Dependencies:** STORY-051 (need auth code from OAuth callback)

**Security note:** This is the most security-sensitive story in the sprint. The Schwab app secret must never touch the iOS binary. The worker-as-proxy pattern is the right call. Flag for `security-auditor`.

---

### STORY-053: Schwab Positions Fetch + Import Preview Screen

**Status:** 🆕 New
**Priority:** P1
**Size:** L
**Type:** Feature
**Story:** As a user who has authorized Schwab, I want to see a preview list of my real Schwab positions (ticker, shares, cost basis) before importing so that I can review exactly what will be added to my portfolio.

**Acceptance Criteria:**
- [ ] After successful token exchange (STORY-052), `SchwabOAuthService` calls `GET https://api.schwabapi.com/trader/v1/accounts/accountNumbers` to get account hash(es), passing `Authorization: Bearer {access_token}`
- [ ] If multiple accounts exist, a picker or list is shown so the user can choose which account to import from
- [ ] Then calls `GET https://api.schwabapi.com/trader/v1/accounts/{accountHash}?fields=positions` to get positions
- [ ] A `SchwabPosition` Swift struct is decoded from the response: `{ symbol, quantity, averagePrice, marketValue }` (Schwab field names: `symbol`, `longQuantity`, `averagePrice`)
- [ ] The Schwab API is called directly from iOS using the bearer token (NOT proxied via the worker — the worker proxy is only needed for token exchange where the secret is required). Direct calls from iOS to Schwab's trader API are fine with a bearer token.
- [ ] A preview screen (`SchwabImportPreviewView`) lists all fetched positions in a `List`
- [ ] Each row shows: ticker symbol, shares (formatted to 4 decimal places for fractional shares), average cost per share (formatted as currency), and an estimated total cost basis
- [ ] Positions with zero quantity are filtered out
- [ ] Options/derivatives (where `assetType != "EQUITY"`) are filtered out — dividend tracker only cares about equities and ETFs
- [ ] Each row has a toggle (default ON) so the user can deselect positions they do not want to import
- [ ] A "Select All / Deselect All" button is in the toolbar
- [ ] The preview screen shows which portfolio the holdings will be added to (portfolio name in the nav title or subtitle)
- [ ] A "Import X Positions" button (disabled when zero selected) triggers STORY-054

**Schwab response shape (abridged):**
```json
{
  "securitiesAccount": {
    "positions": [
      {
        "instrument": { "symbol": "AAPL", "assetType": "EQUITY" },
        "longQuantity": 10.0,
        "averagePrice": 145.23,
        "marketValue": 1832.10
      }
    ]
  }
}
```

**Files to create/modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Services/Schwab/SchwabAPIService.swift` (new — separate from OAuthService; handles trader API calls with bearer token)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Services/Schwab/SchwabModels.swift` (new — `SchwabPosition`, `SchwabAccount`, response wrappers)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/SchwabImportPreviewView.swift` (new)

**Dependencies:** STORY-052 (needs access token)

**Risk:** Schwab returns positions for ALL account types (brokerage, IRA, 401k). Filter to only `type == "MARGIN"` or `"CASH"` accounts, or show all accounts and let the user pick. Confirm filter logic with developer before implementing.

---

### STORY-054: Import Confirmation — Create Holdings in SwiftData

**Status:** 🆕 New
**Priority:** P1
**Size:** M
**Type:** Feature
**Story:** As a user who has reviewed my Schwab positions, I want to tap "Import" and have those positions created as Holdings in my selected Portfolio so that my real brokerage positions are reflected in the app.

**Acceptance Criteria:**
- [ ] Tapping "Import X Positions" on the preview screen triggers the import logic
- [ ] For each selected `SchwabPosition`, the service checks if a `Stock` with that ticker already exists in SwiftData (`FetchDescriptor` with `#Predicate { $0.ticker == symbol }`)
- [ ] If the `Stock` exists, use it; if not, insert a new `Stock` with the ticker symbol and `currentPrice = 0` (price will be fetched by `StockRefreshService` on next refresh)
- [ ] A new `Holding` is inserted: `shares = longQuantity`, `averagesCostBasis = averagePrice`, `purchaseDate = .now`, `externalId = schwabAccountHash + ":" + symbol`
- [ ] The holding is linked to the target `Portfolio` and the resolved `Stock`
- [ ] If a Holding with the same `externalId` already exists in the portfolio (re-import guard), it is skipped and counted separately
- [ ] A summary sheet is shown after import: "Imported 8 positions. 2 skipped (already exist). Tap Done to close."
- [ ] The `modelContext.save()` is called once after all holdings are inserted (not per-holding)
- [ ] On SwiftData save error, the transaction is rolled back and an error alert is shown — no partial import
- [ ] After dismissing the summary, `StockRefreshService.refreshAll()` is triggered in a `Task` to fetch live prices for the newly imported stocks
- [ ] The access token is explicitly nil'd after import completes (even if it would have been deallocated anyway — explicit is better for sensitive data)

**Files to create/modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Services/Schwab/SchwabImportService.swift` (new — pure SwiftData logic, `@MainActor`)
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Portfolios/SchwabImportPreviewView.swift` (wire up import action, show summary)

**Dependencies:** STORY-053 (preview positions), existing `Stock` and `Holding` SwiftData models

**Note:** `externalId` already exists on `Holding` (it was added for exactly this use case — see `Holding.swift` line 12). Use it.

---

### STORY-055: Settings — Schwab App Credentials Entry

**Status:** 🆕 New
**Priority:** P1
**Size:** S
**Type:** Feature
**Story:** As a user setting up the Schwab import, I want to enter my Schwab app key in Settings so that the OAuth flow can be initialized with my registered developer credentials.

**Acceptance Criteria:**
- [ ] A new "Schwab Integration" section appears in `SettingsView` (below the existing API key section)
- [ ] A secure text field (or standard text field — app key is not a password) accepts the Schwab App Key
- [ ] The app key is stored in Keychain under the key `"schwabAppKey"` using the existing `KeychainService`
- [ ] The app key is NOT stored in `SettingsStore` / `UserDefaults` — Keychain only
- [ ] A status indicator shows "Connected" (green dot) if a key is saved, "Not configured" (gray) if not
- [ ] A "Remove" button clears the Keychain entry and resets the indicator to "Not configured"
- [ ] The Schwab App Secret is NOT entered by the user — it lives only in the Cloudflare Worker as a Wrangler secret (see STORY-052). This must be clearly communicated in the UI: "Your Schwab App Secret is stored securely in the server proxy — not on this device."
- [ ] A "Learn more" link (opens a modal or Safari) explains the setup steps: register at developer.schwab.com, create an app with readonly scope, copy the app key here
- [ ] If the user taps "Import from Schwab" without having entered an app key, a sheet is shown directing them to Settings to configure it first

**Files to modify:**
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Features/Settings/SettingsView.swift`
- `/Users/arthurdudkoagent_1/Developer/MyApp/MyApp/Core/Services/Schwab/SchwabOAuthService.swift` (read app key from Keychain)

**Dependencies:** None (can be built and shipped independently; must be done before STORY-051)

---

## Dependency Map — Sprint 17

```
STORY-055 (Settings: enter Schwab app key)          — no deps; must ship first
  └─ STORY-051 (OAuth login via ASWebAuthSession)   — needs app key from Keychain
       └─ STORY-052 (Token exchange via CF Worker)  — needs auth code from STORY-051
            └─ STORY-053 (Fetch positions + preview) — needs access token from STORY-052
                 └─ STORY-054 (Create Holdings)      — needs selected positions from STORY-053
```

## Architecture Decisions — Sprint 17

### Decision 1: One-time import vs. live sync
**Choice: One-time import only (MVP)**
Rationale: Schwab access tokens expire in 30 min, refresh tokens expire in 7 days. Live sync requires background token refresh and persistent refresh token storage in Keychain. That is a significant surface area for auth bugs and complicates the UX ("why is my data stale?"). For a solo dev free app, one-time import on demand is the right call. The user can re-import at any time by tapping the button again — the re-import guard (externalId dedup) prevents duplicates.
Revisit: Add refresh token persistence in a later sprint if users request live sync.

### Decision 2: Where does the Schwab App Secret live?
**Choice: Cloudflare Worker only**
The iOS binary cannot safely hold the Schwab App Secret — it would be extractable from the IPA. The existing Cloudflare Worker proxy is the right place. The worker holds `SCHWAB_APP_KEY` and `SCHWAB_APP_SECRET` as Wrangler secrets. The iOS app only stores the App Key (needed for building the OAuth authorization URL — this is a public identifier, not a secret).

### Decision 3: Direct Schwab API calls for positions (no worker proxy)
**Choice: iOS calls Schwab Trader API directly with bearer token**
The worker proxy was needed for the Massive API because the Massive API key is a long-lived secret. The Schwab bearer token is ephemeral (30 min) and is the user's own credential — it is appropriate for the iOS client to use it directly. Routing position fetches through the worker adds latency and complexity with no security benefit.

### Decision 4: Token lifetime and storage
**Choice: In-memory only, discarded after import**
Tokens are held as `@State` (or a local variable in a service) in the import sheet. They are not written to Keychain, UserDefaults, or any persistent store. When the sheet is dismissed, the tokens are deallocated. This is the simplest, most secure approach for a one-time import flow.

---

## Open Questions — Sprint 17 (need developer answers before stories start)

| # | Question | Impact | Default if no answer |
|---|---|---|---|
| 1 | Where does "Import from Schwab" button live: Portfolios list toolbar, or inside PortfolioHoldingsView? | Determines where the target portfolio is selected | Default: inside PortfolioHoldingsView (target portfolio is explicit) |
| 2 | What redirect URI scheme should be used? Must match Schwab developer portal registration. | STORY-051 cannot start without this | Default: `myapp://schwab/callback` |
| 3 | Does the developer already have a Schwab developer account and registered app? | Unblocks STORY-055 | Assume not yet — STORY-055 includes setup instructions |
| 4 | Should the Cloudflare Worker hold the Schwab App Key AND Secret, or just the Secret? | If Worker holds both, the iOS Settings entry for app key is unnecessary | Decision 2 above assumes iOS holds app key (public), Worker holds secret only |
| 5 | How should re-import behave for changed positions (e.g. user bought more shares)? | STORY-054 currently skips existing externalIds — should it update shares/cost basis instead? | Default: skip existing, user edits manually. Can revisit. |

---

## Items Flagged for Clarification or Feasibility Review

| Request | Reason |
|---|---|
| Request #2 "colored fonts in settings" — as full font color theming | Scoped down to STORY-050 (accent color theming, not arbitrary per-font color overrides). Full per-font color control is an accessibility concern and adds significant complexity for unclear user value. |
| Request #8 "All Weather Portfolio" as a live-rebalancing feature | Scoped to static strategy templates only (STORY-045). Live rebalancing requires brokerage API integration which is out of scope for this app. |

---

## Completed Stories (Archive)

| ID | Story | Sprint | Commit |
|---|---|---|---|
| STORY-001 to STORY-018 | Core models, Massive service, StockRefreshService, DividendCalendar, sequential refresh | 1–3 | — |
| STORY-019 | Dashboard swipe pages | 4 | `ba4eb38` |
| STORY-020 | Portfolios tab | 4 | `ba4eb38` |
| STORY-021 | Stocks browser + StockDetailView | 4 | `ba4eb38` |
| STORY-022 | MassiveModels — new endpoint models | 6 | `9b9fff7` |
| STORY-023 | MassiveService — implement new fetch methods | 6 | `9b9fff7` |
| STORY-024 | MockMassiveService — extend mock | 6 | `9b9fff7` |
| STORY-025 | News — article thumbnail images | 7 | `9b9fff7` |
| STORY-026 | Stock search — CS/ETF/PFD type badges | 7 | `9b9fff7` |
| STORY-027 | Stock Detail — real financials | 8 | `9b9fff7` |
| STORY-028 | Stock Detail — historical price chart | 8 | `9b9fff7` |
| STORY-029 | Stock Detail — technical indicators | 8 | `9b9fff7` |
| STORY-030 | Stock Detail — related companies | 8 | `9b9fff7` |
| STORY-031 | Stock Detail — stock split history | 8 | `9b9fff7` |
| STORY-032 | Market status banner | 9 | `9b9fff7` |
| STORY-033 | Dividend calendar — market holiday indicators | 9 | `9b9fff7` |
| STORY-034 | StockRefreshService — skip refresh when closed | 9 | `9b9fff7` |
| STORY-035 | Grouped daily batch refresh | 10 | `9b9fff7` |
| STORY-036 | Previous close fallback | 10 | `9b9fff7` |
| STORY-037 | Ticker type labels | 11 | `9b9fff7` |
| STORY-038 | Exchange display names | 11 | `9b9fff7` |
| STORY-039 | Fix: Calendar tap dates | 12 | `12f4dc6` |
| STORY-040 | Fix: Crypto search | 12 | `12f4dc6` |
| STORY-041 | Calendar: Dividend amounts | 12 | `479e5e5` |
| STORY-042 | Calendar: Month summary | 12 | `479e5e5` |
| STORY-043 | Stock search filters | 12 | `479e5e5` |
| STORY-044 | Auto-select portfolio | 13 | — |
| STORY-045 | Dividend strategies | 13 | — |
| STORY-046 | Income history view | 13 | — |
| STORY-047 | Holding context menu | 14 | — |
| STORY-048 | Future Value modal | 14 | — |
| STORY-049 | Investing quotes | 15 | — |
| STORY-050 | Font theme | 16 | — |

---

## Sprint 18 — Stock Intelligence (Screener, Signal Scores, AI Reports, Risk Analysis)

**Sprint goal:** Give dividend investors a research-grade edge without leaving the app. Surface composite signal scores, AI-generated bear/bull narratives, analyst price targets, and rule-based risk flags — all grounded in data that is either free or already paid for.

**Full sprint plan:** `/Users/arthurdudkoagent_1/Developer/MyApp/.claude/pm/sprint-18-stock-intelligence.md`

| ID | Story | Type | Priority | Size | Status |
|---|---|---|---|---|---|
| STORY-056 | Finnhub API integration (Keychain, proxy route, FinnhubFetching protocol) | Foundation | P0 | S | 🆕 New |
| STORY-057 | Dividend Signal Score (rule-based composite score calculator) | Feature | P1 | M | 🆕 New |
| STORY-058 | Stock Screener view (sortable table, signal badges, search) | Feature | P1 | M | 🆕 New |
| STORY-059 | Analyst Price Target card (bear/target/bull gradient bar in StockDetailView) | Feature | P1 | M | 🆕 New |
| STORY-060 | AI Research Report (bear/bull narratives via Claude Haiku + CF Worker) | Feature | P2 | L | 🆕 New |
| STORY-061 | Risk Analysis — rule-based Phase 1 (8 financial risk rules + RiskFactorsCard) | Feature | P1 | M | ✅ Done |
| STORY-062 | Report cache layer (CacheStore, Cacheable protocol, TTL expiry) | Infrastructure | P1 | S | 🆕 New |

**Dependency order:**
- STORY-056 first (blocks 057, 059, 060); STORY-061 and STORY-062 can start immediately in parallel
- STORY-057 + STORY-059 + STORY-062 can run in parallel after STORY-056
- STORY-058 after STORY-057; STORY-060 after STORY-056 + STORY-059 + STORY-062

---

## Definition of Done (all stories)

- Implementation complete and compiles with zero warnings
- `code-reviewer` passed
- `security-auditor` passed
- `ios-reviewer` passed
- `test-reviewer` passed
- `frontend-reviewer` passed (all SwiftUI view files)
