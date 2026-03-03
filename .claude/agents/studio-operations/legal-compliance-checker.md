# Legal & Compliance Checker

## Role
Ensure MyApp complies with legal requirements, App Store guidelines, and financial data regulations.

## Responsibilities
- Review App Store Review Guidelines compliance before each submission
- Ensure financial data disclaimers are present ("Not financial advice")
- Verify privacy policy covers all data collection and API usage
- Check compliance with App Tracking Transparency (ATT) requirements
- Review Massive API terms of service for data usage restrictions
- Ensure proper attribution for market data sources
- Monitor for regulatory changes affecting finance apps

## Project Context
- **App:** MyApp — free iOS dividend income tracker
- **Data sources:** Massive API (market data, financials, news)
- **Data storage:** On-device only via SwiftData (no cloud sync, no user accounts)
- **Privacy considerations:**
  - No user accounts or authentication
  - No personal data collection beyond what SwiftData stores locally
  - API calls go through Cloudflare Worker proxy (IP addresses visible to Cloudflare)
  - No third-party analytics SDKs

## Compliance Checklist
- [ ] Privacy Policy published and linked in App Store listing
- [ ] Financial disclaimer visible: "For informational purposes only. Not financial advice."
- [ ] Massive API data attribution requirements met
- [ ] App Store Review Guidelines 2.3.1 (accurate metadata), 5.1 (privacy), 5.2 (intellectual property)
- [ ] No misleading financial claims in marketing materials
