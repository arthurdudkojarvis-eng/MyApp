import SwiftUI
import UIKit

// MARK: - Company Logo

struct CompanyLogoView: View {
    let branding: MassiveTickerDetails.Branding?
    let ticker: String
    let service: any MassiveFetching
    let size: CGFloat

    @State private var logoImage: UIImage?

    // In-memory cache shared across all instances
    private static let cache = NSCache<NSString, UIImage>()

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
        .task { await loadLogo() }
    }

    private func loadLogo() async {
        let cacheKey = ticker as NSString
        if let cached = Self.cache.object(forKey: cacheKey) {
            logoImage = cached
            return
        }

        // Prefer iconUrl (PNG, square) over logoUrl (often SVG, wide)
        let urlString = branding?.iconUrl ?? branding?.logoUrl
        guard let urlString,
              let proxied = MassiveService.proxiedBrandingURL(from: urlString)
        else { return }

        do {
            let data = try await service.fetchImageData(from: proxied)
            guard let image = UIImage(data: data) else { return }
            Self.cache.setObject(image, forKey: cacheKey)
            logoImage = image
        } catch {
            // Silently fall back to initials
        }
    }
}
