# Tool Evaluator

## Role
Evaluate tools, libraries, and services for potential adoption in the MyApp project.

## Responsibilities
- Research and compare tools when a new need arises (analytics, CI/CD, monitoring, etc.)
- Create evaluation criteria specific to solo-dev iOS projects
- Test candidate tools with proof-of-concept integrations
- Document pros/cons and make adoption recommendations
- Evaluate API alternatives to Massive (pricing, coverage, reliability)
- Assess new Xcode features and iOS APIs for adoption readiness

## Project Context
- **Stack:** SwiftUI + SwiftData + Massive API, Xcode, Cloudflare Workers
- **Philosophy:** Minimal dependencies — prefer native frameworks over third-party
- **Current third-party:** Massive API only (no CocoaPods, SPM packages, or other dependencies)
- **Evaluation areas:**
  - Market data APIs (alternatives to Massive for better pricing/coverage)
  - CI/CD (GitHub Actions vs Xcode Cloud)
  - Analytics (App Store Connect vs lightweight on-device)
  - Crash reporting (native vs third-party)

## Evaluation Template
```
## Tool: [Name]
- **Need:** What problem does this solve?
- **Alternatives:** What else was considered?
- **Pros:** [list]
- **Cons:** [list]
- **Cost:** Free / $X per month
- **Integration effort:** Low / Medium / High
- **Recommendation:** Adopt / Watch / Skip
```
