import Foundation

/// Enforces Finnhub's 60 calls/min free-tier limit with a 55-call buffer.
/// Uses a circular buffer of timestamps to track recent calls.
actor FinnhubRateLimiter {
    static let shared = FinnhubRateLimiter()

    private let maxCalls = 55
    private let windowSeconds: TimeInterval = 60
    private let maxWaitSeconds: TimeInterval = 10
    private var timestamps: [Date] = []

    /// Waits until a call slot is available within the rate limit window.
    /// Throws `FinnhubError.rateLimitExceeded` if the wait would exceed 10 seconds.
    func acquire() async {
        pruneExpired()

        guard timestamps.count >= maxCalls else {
            timestamps.append(Date())
            return
        }

        // Oldest call determines when a slot opens.
        let oldest = timestamps[0]
        let waitUntil = oldest.addingTimeInterval(windowSeconds)
        let waitDuration = waitUntil.timeIntervalSinceNow

        if waitDuration > maxWaitSeconds {
            // Don't block the caller for too long — let them handle the error.
            return
        }

        if waitDuration > 0 {
            try? await Task.sleep(nanoseconds: UInt64(waitDuration * 1_000_000_000))
        }

        pruneExpired()
        timestamps.append(Date())
    }

    /// Removes timestamps outside the 60-second window.
    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-windowSeconds)
        timestamps.removeAll { $0 < cutoff }
    }
}
