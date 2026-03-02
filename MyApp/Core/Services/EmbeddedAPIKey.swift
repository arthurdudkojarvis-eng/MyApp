import Foundation

/// Stores the built-in API key using XOR obfuscation so it cannot be
/// extracted from the binary with `strings`. Run the generator script
/// to produce real values:
///
///     swift Scripts/generate_obfuscated_key.swift "YOUR_KEY"
///
/// Then paste the output arrays below.
enum EmbeddedAPIKey {
    // MARK: - Placeholder bytes (replace with generator output)

    private static let obfuscated: [UInt8] = [
        // paste obfuscated bytes here
    ]

    private static let mask: [UInt8] = [
        // paste mask bytes here
    ]

    /// Recovers the plaintext key by XOR-ing `obfuscated` with `mask`.
    static var key: String {
        guard !obfuscated.isEmpty, obfuscated.count == mask.count else {
            assertionFailure("EmbeddedAPIKey: arrays missing or mismatched — run generate_obfuscated_key.swift")
            return ""
        }
        let bytes = zip(obfuscated, mask).map { $0 ^ $1 }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
}
