# MyApp — Product Backlog

**Stack:** SwiftUI + SwiftData + Massive API (Starter $29/mo) + Cloudflare Worker proxy
**Platform:** iOS 17+, Solo dev, Free app
**Last updated:** 2026-03-03

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

## Descoped / Not Recommended

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

## Definition of Done (all stories)

- Implementation complete and compiles with zero warnings
- `code-reviewer` passed
- `security-auditor` passed
- `ios-reviewer` passed
- `test-reviewer` passed
- `frontend-reviewer` passed (all SwiftUI view files)
