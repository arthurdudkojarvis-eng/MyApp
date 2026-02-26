import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var retryToken = 0

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    contentView
                }
            }
            .navigationTitle("Home")
            .task(id: retryToken) {
                await viewModel.loadData()
            }
        }
    }

    private var contentView: some View {
        VStack(spacing: 16) {
            Text(viewModel.greeting)
                .font(.title)
                .fontWeight(.bold)

            Text("Build something great.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text(message)
                .multilineTextAlignment(.center)

            Button("Retry") {
                retryToken += 1
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    HomeView()
}
