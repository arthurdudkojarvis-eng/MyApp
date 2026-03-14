import SwiftUI

// MARK: - Environment key for FinnhubFetching
// Same pattern as MassiveEnvironment.swift — wraps the existential in a
// reference-type box so SwiftUI can diff by pointer equality.

// `@unchecked Sendable` is safe: `service` is `let`-immutable and `FinnhubFetching`
// itself requires `Sendable`, so there is no shared mutable state.
final class FinnhubServiceBox: @unchecked Sendable {
    let service: any FinnhubFetching
    init(_ service: any FinnhubFetching) { self.service = service }
}

private struct FinnhubServiceKey: EnvironmentKey {
    static let defaultValue = FinnhubServiceBox(FinnhubService())
}

extension EnvironmentValues {
    var finnhubService: FinnhubServiceBox {
        get { self[FinnhubServiceKey.self] }
        set { self[FinnhubServiceKey.self] = newValue }
    }
}
