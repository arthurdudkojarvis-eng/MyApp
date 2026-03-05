import SwiftUI
import UIKit

// MARK: - Branding Cache (actor-isolated for thread safety)

private actor BrandingStore {
    static let shared = BrandingStore()
    // Stores Optional<Branding> — nil value means "fetched but no branding available"
    private var cache: [String: MassiveTickerDetails.Branding?] = [:]

    func get(_ ticker: String) -> MassiveTickerDetails.Branding?? {
        cache[ticker]    // nil = not fetched; .some(nil) = fetched, no branding
    }

    func set(_ ticker: String, branding: MassiveTickerDetails.Branding?) {
        cache[ticker] = branding
    }
}

// MARK: - Company Logo

struct CompanyLogoView: View {
    let branding: MassiveTickerDetails.Branding?
    let ticker: String
    let service: any MassiveFetching
    let size: CGFloat

    @State private var logoImage: UIImage?

    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    var body: some View {
        Group {
            if let image = logoImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            } else {
                // Fallback: ticker initials in accent circle
                Text(String(ticker.prefix(2)))
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .task(id: ticker) { await loadLogo() }
    }

    @MainActor
    private func loadLogo() async {
        logoImage = nil
        let cacheKey = ticker as NSString

        // 1. Check image cache
        if let cached = Self.imageCache.object(forKey: cacheKey) {
            logoImage = cached
            return
        }

        // 2. Resolve branding — use provided, actor-cached, or fetch from API
        let resolvedBranding: MassiveTickerDetails.Branding?
        if let branding {
            resolvedBranding = branding
        } else if let cached = await BrandingStore.shared.get(ticker) {
            // Double-optional: .some(nil) means "already tried, no branding"
            resolvedBranding = cached
        } else {
            let details = try? await service.fetchTickerDetails(ticker: ticker)
            guard !Task.isCancelled else { return }
            // Always cache (even nil) to prevent re-fetching
            await BrandingStore.shared.set(ticker, branding: details?.branding)
            resolvedBranding = details?.branding
        }

        // 3. Pick best non-SVG URL
        let urlString = preferredLogoURL(from: resolvedBranding)
        guard let urlString,
              let proxied = MassiveService.proxiedBrandingURL(from: urlString)
        else { return }

        // 4. Download and decode logo image
        do {
            let data = try await service.fetchImageData(from: proxied)
            guard !Task.isCancelled else { return }
            guard data.count <= 512 * 1024 else { return } // 500 KB max
            let image = await Task.detached(priority: .utility) {
                UIImage(data: data)
            }.value
            guard let image else { return }
            Self.imageCache.setObject(image, forKey: cacheKey)
            logoImage = image
        } catch {
            // Silently fall back to initials
        }
    }

    private func preferredLogoURL(from branding: MassiveTickerDetails.Branding?) -> String? {
        guard let branding else { return nil }
        if let icon = branding.iconUrl, !icon.lowercased().hasSuffix(".svg") {
            return icon
        }
        if let logo = branding.logoUrl, !logo.lowercased().hasSuffix(".svg") {
            return logo
        }
        return nil
    }
}
