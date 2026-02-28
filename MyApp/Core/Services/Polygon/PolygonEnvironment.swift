import SwiftUI

// MARK: - Environment key for PolygonFetching
// Injects `PolygonService` by default; tests override with a mock.
//
// The existential `any PolygonFetching` is not Equatable, so SwiftUI cannot
// diff it and would re-render every observer on every environment update.
// Wrapping in a reference-type box provides pointer-equality stability so
// SwiftUI only re-renders when the box instance itself changes.

// `@unchecked Sendable` is safe: `service` is `let`-immutable and `PolygonFetching`
// itself requires `Sendable`, so there is no shared mutable state.
final class PolygonServiceBox: @unchecked Sendable {
    let service: any PolygonFetching
    init(_ service: any PolygonFetching) { self.service = service }
}

private struct PolygonServiceKey: EnvironmentKey {
    static let defaultValue = PolygonServiceBox(PolygonService())
}

extension EnvironmentValues {
    var polygonService: PolygonServiceBox {
        get { self[PolygonServiceKey.self] }
        set { self[PolygonServiceKey.self] = newValue }
    }
}
