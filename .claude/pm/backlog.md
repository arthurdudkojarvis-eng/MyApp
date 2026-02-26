# Dividend Income Tracker — MVP Backlog

**Design direction:** Calm & Minimal (Robinhood/Ivory style)
**Stack:** SwiftUI, SwiftData, Polygon.io API, StoreKit 2
**Target:** iOS 17+, one-time App Store purchase
**Developer:** Solo

---

## Sprint 1 — Foundation

| ID | Story | Priority | Size | Status |
|---|---|---|---|---|
| STORY-001 | SwiftData Schema Setup | Critical | M | ✅ Done |
| STORY-002 | App Shell & Navigation Structure | Critical | S | ✅ Done |
| STORY-003 | Settings Screen (Foundation) | High | S | ✅ Done |
| STORY-004 | Portfolio Creation | Critical | S | ✅ Done |

**Sprint goal:** App launches, navigation works, data layer is in place, settings are configurable.

---

## Sprint 2 — Core Features

| ID | Story | Priority | Size | Status |
|---|---|---|---|---|
| STORY-005 | Add Holding (Manual Entry) | Critical | M | ✅ Done |
| STORY-006 | Holdings List View | Critical | M | ✅ Done |
| STORY-007 | Holding Detail View | High | M | ✅ Done |
| STORY-008 | Stock Data Fetching (Polygon.io) | Critical | L | 🆕 New |
| STORY-009 | Income Dashboard — Hero Screen | Critical | L | 🆕 New |
| STORY-010 | Coverage Meter | High | M | 🆕 New |
| STORY-011 | Dividend Calendar View | High | L | 🆕 New |
| STORY-012 | Dividend Payment Logging | High | M | 🆕 New |

**Sprint goal:** App works end-to-end. User can add holdings, see income dashboard, view dividend calendar, log received payments.

---

## Sprint 3 — Polish & Shipping

| ID | Story | Priority | Size | Status |
|---|---|---|---|---|
| STORY-013 | App Icon & Launch Screen | High | S | ✅ Done |
| STORY-014 | Light and Dark Mode | High | S | 🆕 New |
| STORY-015 | Empty States & Error States | Medium | S | 🆕 New |
| STORY-016 | StoreKit One-Time Purchase | Medium | M | 🆕 New |
| STORY-017 | Onboarding Flow | Medium | S | 🆕 New |
| STORY-018 | Performance & Data Integrity | Medium | M | 🆕 New |

**Sprint goal:** App is shippable. Icon, purchase, edge cases, both appearance modes.

---

## Sprint 4 — Navigation & Discovery

| ID | Story | Priority | Size | Status |
|---|---|---|---|---|
| STORY-019 | Dashboard Swipe Navigation | Medium | S | 🆕 New |
| STORY-020 | Portfolios Tab with Performance Indicators | High | M | 🆕 New |
| STORY-021 | Stock Browser Tab | High | L | 🆕 New |

**Sprint goal:** Expand navigational depth and discoverability. Users can swipe between dashboard pages, view portfolio-level performance at a glance, and browse/search stocks with key dividend criteria before adding them to a portfolio.

---

### STORY-019: Dashboard Swipe Navigation

**As a** user on the main Dashboard tab,
**I want to** swipe left to reveal a second dashboard page,
**so that** additional summary views can be surfaced without cluttering the primary screen.

**Acceptance criteria:**
- The Dashboard tab supports a horizontal swipe gesture that slides to a second page.
- The second page has a solid black background.
- The second page displays placeholder section headers only — no live content.
- The headers are clearly labelled to signal intent (reserved for future features).
- Swiping right from the second page returns to the primary dashboard page.
- Page indicator dots (or equivalent affordance) show which page is active.
- No content, charts, or data are rendered on the second page in this story.

**Notes:** Keep the gesture implementation lightweight — a `TabView` with `.page` style or a `ScrollView` with paging enabled are both acceptable. Placeholder headers must be approved before story is closed.

---

### STORY-020: Portfolios Tab with Performance Indicators

**As a** user with one or more portfolios,
**I want to** see each portfolio summarised as a card with performance at a glance,
**so that** I can quickly assess which portfolios are growing or losing value without drilling into each one.

**Acceptance criteria:**
- A dedicated Portfolios tab exists in the main tab bar.
- Each portfolio is displayed as a card containing:
  - Portfolio name
  - Total market value (Σ currentPrice × shares across all holdings)
  - Projected monthly income (Σ annualDividendPerShare × shares / 12)
  - Unrealized gain/loss displayed as both a dollar amount and a percentage
- Gain/loss is rendered in green when positive, red when negative, and neutral (system label color) when zero.
- Unrealized gain/loss formula per holding: `((currentPrice − averageCostBasis) / averageCostBasis) × 100`; values are aggregated across all holdings in the portfolio for the portfolio-level figure.
- Dollar gain/loss formula: `(currentPrice − averageCostBasis) × shares` summed across holdings.
- Tapping a portfolio card navigates into the existing `HoldingDetailView` holdings list for that portfolio.
- The tab displays an appropriate empty state when no portfolios exist.
- Cards refresh when the view appears (pull-to-refresh is a bonus, not required).

**Notes:** Reuse `HoldingDetailView` for the drill-down — no new detail screen needed. Market value and gain/loss depend on `currentPrice` being available from Polygon.io (STORY-008); show a loading/unavailable state gracefully if price data is absent.

---

### STORY-021: Stock Browser Tab

**As a** user researching dividend stocks,
**I want to** search for any ticker and see its key dividend criteria on a single card,
**so that** I can evaluate a stock and add it to a portfolio without leaving the app.

**Acceptance criteria:**
- A dedicated Stocks tab exists in the main tab bar.
- The tab contains a search bar at the top. Typing a ticker symbol queries Polygon.io via the existing `PolygonService`.
- Each search result is displayed as a stock card containing:
  - Company name and ticker symbol
  - Sector
  - Mini-dashboard of 6 key criteria:
    1. Dividend Yield (%)
    2. Annual Dividend per Share ($)
    3. Ex-Dividend Date
    4. Payout Ratio (%)
    5. P/E Ratio
    6. Market Cap
  - Fields that are unavailable from the API are shown as "—" rather than blank or crashing.
- Each card has an Add / Remove button:
  - If the ticker is not present in any portfolio: button reads "Add" and tapping opens `AddHoldingView` with the ticker field pre-filled.
  - If the ticker is already in at least one portfolio: button reads "Remove" and tapping opens `HoldingDetailView` for that holding.
- All data is sourced from `PolygonService` (no new networking layer introduced).
- An empty state is shown when no search has been performed yet.
- An error state is shown if the Polygon.io request fails.

**Notes:** Payout Ratio and P/E Ratio may not be available on all Polygon.io endpoints — use `GET /v3/reference/tickers/{ticker}` for fundamentals and `GET /v3/reference/dividends?ticker={ticker}` for dividend data. Graceful degradation for missing fields is required. "Remove" navigates to the detail view rather than deleting silently — destructive actions must be user-initiated from within the detail view.

---

## Phase 2 Backlog (Post-Launch)

- Broker sync (Plaid or direct brokerage APIs)
- iCloud sync across devices
- DRIP reinvestment modeling
- Multiple coverage meter targets
- Home screen widget (monthly income)
- Tax export — Schedule B CSV
- Dividend safety scoring

---

## Data Model Reference

```
Portfolio       → has many Holdings
Holding         → belongs to Portfolio, belongs to Stock
Stock           → has many DividendSchedules
DividendSchedule → has many DividendPayments
DividendPayment → belongs to Holding, belongs to DividendSchedule
```

## Key Formulas

- **Yield on Cost** = (annualDividendPerShare / averageCostBasis) × 100
- **Projected Annual Income** = Σ (annualDividendPerShare × shares) per holding
- **Monthly Projected Income** = Projected Annual Income / 12
- **Coverage %** = (monthlyProjectedIncome / monthlyExpenseTarget) × 100

## API Reference

- Polygon.io ticker details: `GET /v3/reference/tickers/{ticker}`
- Polygon.io dividends: `GET /v3/reference/dividends?ticker={ticker}`
- Polygon.io previous close: `GET /v2/aggs/ticker/{ticker}/prev`
- API key stored in Keychain, never in UserDefaults or source code
