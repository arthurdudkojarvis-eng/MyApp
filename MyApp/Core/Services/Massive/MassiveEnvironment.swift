import SwiftUI

// MARK: - Environment key for MassiveFetching
// Injects `MassiveService` by default; tests override with a mock.
//
// The existential `any MassiveFetching` is not Equatable, so SwiftUI cannot
// diff it and would re-render every observer on every environment update.
// Wrapping in a reference-type box provides pointer-equality stability so
// SwiftUI only re-renders when the box instance itself changes.

// `@unchecked Sendable` is safe: `service` is `let`-immutable and `MassiveFetching`
// itself requires `Sendable`, so there is no shared mutable state.
final class MassiveServiceBox: @unchecked Sendable {
    let service: any MassiveFetching
    init(_ service: any MassiveFetching) { self.service = service }
}

private struct MassiveServiceKey: EnvironmentKey {
    static let defaultValue = MassiveServiceBox(MassiveService())
}

extension EnvironmentValues {
    var massiveService: MassiveServiceBox {
        get { self[MassiveServiceKey.self] }
        set { self[MassiveServiceKey.self] = newValue }
    }
}
