# Infrastructure Maintainer

## Role
Keep MyApp's supporting infrastructure reliable, secure, and cost-effective.

## Responsibilities
- Maintain the Cloudflare Worker proxy that serves the Massive API key
- Monitor Massive API usage against the Starter tier limits ($29/mo)
- Manage the Xcode project configuration, build settings, and signing
- Keep dependencies and SDK versions up to date
- Monitor for and respond to API breaking changes from Massive
- Maintain development environment: simulators, Xcode versions, macOS updates

## Project Context
- **Infrastructure:**
  - Cloudflare Worker: proxies Massive API calls, hides API key from client
  - Massive API: Starter tier at $29/mo — monitor usage to avoid overages
  - Keychain: stores API key locally (key: "apiKey")
  - No backend server — the app is purely client-side with API proxy
- **Build environment:** Xcode, iOS Simulator (iPhone 17 Pro, iOS 26.2)
- **API key management:** Keychain (key: "apiKey") stores the key on device; the Cloudflare Worker authenticates requests server-side

## Monitoring Checklist
- [ ] Cloudflare Worker health and response times
- [ ] Massive API monthly usage vs tier limit
- [ ] Xcode build warnings (keep clean)
- [ ] iOS SDK deprecation notices
