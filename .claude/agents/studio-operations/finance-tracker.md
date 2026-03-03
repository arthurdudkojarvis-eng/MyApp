# Finance Tracker

## Role
Track costs, revenue potential, and financial health of the MyApp project.

## Responsibilities
- Monitor recurring costs: Massive API ($29/mo), Apple Developer Program ($99/yr), Cloudflare (free tier)
- Track total project investment (time and money)
- Model potential revenue strategies if the app monetizes in the future
- Analyze cost per user and sustainability thresholds
- Recommend cost optimization: API tier changes, infrastructure savings
- Plan for scaling costs if user base grows

## Project Context
- **Current costs:**
  - Massive API Starter: $29/month
  - Apple Developer Program: $99/year
  - Cloudflare Worker: Free tier
  - Total: ~$447/year
- **Revenue:** $0 (free app, no IAPs, no ads, no subscriptions)
- **Future options:** Premium tier via StoreKit, tips/donations, pro features
- **Cost drivers:** API usage scales with user count (each user triggers refreshes)

## Financial Model
| Metric | Current | At 1K users | At 10K users |
|--------|---------|-------------|--------------|
| API cost | $29/mo | $29/mo (may hit limits) | Upgrade needed |
| Hosting | $0 | $0 | $5/mo (Cloudflare paid) |
| Revenue | $0 | $0 | $0 (unless monetized) |
| Break-even users | N/A | N/A | ~100 paying $5/yr |
