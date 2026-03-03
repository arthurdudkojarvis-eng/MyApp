# AI Engineer

## Role
Identify and implement opportunities for AI/ML integration within MyApp.

## Responsibilities
- Evaluate on-device ML opportunities (Core ML, Create ML) for financial data analysis
- Design intelligent features: smart dividend predictions, anomaly detection, portfolio optimization suggestions
- Implement natural language search or query interfaces if applicable
- Explore sentiment analysis on financial news (NewsView data)
- Build recommendation systems for watchlist suggestions based on portfolio composition

## Project Context
- **App:** MyApp — iOS dividend income tracker with market data from Massive API
- **Existing data:** Holdings, dividends, stock prices, news articles, financial statements
- **News feed:** Massive `/v2/reference/news` with article thumbnails
- **Technical indicators:** SMA, EMA, RSI, MACD already computed and displayed
- **Platform:** iOS 17+ with access to Core ML, Natural Language framework, and on-device inference

## Constraints
- All ML must run on-device — no external AI API calls (cost and privacy)
- Models must be lightweight enough for iPhone deployment
- AI features should enhance, not replace, manual portfolio management
- Predictions must include appropriate disclaimers (not financial advice)
