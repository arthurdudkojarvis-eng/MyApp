import SwiftData
import SwiftUI
import OSLog

private let cacheLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.divvy.Divvy",
                                  category: "CacheStore")

// MARK: - Cacheable protocol

protocol Cacheable: PersistentModel {
    var ticker: String { get }
    var fetchedAt: Date { get set }
    static var defaultTTL: TimeInterval { get }
}

// MARK: - CacheStore

@MainActor @Observable
final class CacheStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func get<T: Cacheable>(ticker: String) -> T? {
        let upperTicker = ticker.uppercased()
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.ticker == upperTicker }
        )
        guard let entry = try? modelContext.fetch(descriptor).first else { return nil }
        guard Date.now.timeIntervalSince(entry.fetchedAt) <= T.defaultTTL else { return nil }
        return entry
    }

    func set<T: Cacheable>(ticker: String, value: T) {
        let upperTicker = ticker.uppercased()
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.ticker == upperTicker }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
        }
        modelContext.insert(value)
        do {
            try modelContext.save()
        } catch {
            cacheLogger.error("CacheStore save failed for \(ticker): \(error)")
        }
    }
}

// MARK: - Environment key

private struct CacheStoreKey: EnvironmentKey {
    static let defaultValue: CacheStore? = nil
}

extension EnvironmentValues {
    var cacheStore: CacheStore? {
        get { self[CacheStoreKey.self] }
        set { self[CacheStoreKey.self] = newValue }
    }
}
