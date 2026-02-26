import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var greeting: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        greeting = ""
        defer { isLoading = false }

        do {
            // Replace with real data fetching
            try await Task.sleep(for: .milliseconds(300))
            greeting = "Welcome to MyApp"
        } catch is CancellationError {
            // Task cancelled — reset silently
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }
    }
}
