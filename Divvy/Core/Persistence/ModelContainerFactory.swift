import SwiftData

extension ModelContainer {

    static let appSchema = Schema([
        Portfolio.self,
        Holding.self,
        Stock.self,
        DividendSchedule.self,
        DividendPayment.self,
        WatchlistItem.self,
        PriceTargetCache.self
    ])

    /// Persistent on-disk container used by the production app.
    static let app: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            // Container creation failure is unrecoverable at launch.
            // TODO: Before shipping, add a migration error screen instead of crashing.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// In-memory container for SwiftUI Previews.
    static let preview: ModelContainer = {
        do {
            return try makeContainer(inMemory: true)
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()

    /// Throwing factory — use in unit tests to get a fresh isolated container.
    ///
    ///     let container = try ModelContainer.makeContainer(inMemory: true)
    ///
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: appSchema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: appSchema, configurations: [config])
    }
}
