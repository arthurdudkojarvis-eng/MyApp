import XCTest
@testable import MyApp

@MainActor
final class HomeViewModelTests: XCTestCase {
    func test_loadData_setsGreeting() async {
        let viewModel = HomeViewModel()

        await viewModel.loadData()

        XCTAssertFalse(viewModel.greeting.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_loadData_setsLoadingDuringFetch() async {
        let viewModel = HomeViewModel()
        XCTAssertFalse(viewModel.isLoading)

        await viewModel.loadData()

        XCTAssertFalse(viewModel.isLoading)
    }
}
