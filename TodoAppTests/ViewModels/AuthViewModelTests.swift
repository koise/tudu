import XCTest
import Combine

@MainActor
final class AuthViewModelTests: XCTestCase {

    var sut: AuthViewModel!
    var mockRepo: MockAuthRepository!

    override func setUp() {
        super.setUp()
        mockRepo = MockAuthRepository()
        sut = AuthViewModel(repo: mockRepo)
    }

    override func tearDown() {
        sut = nil
        mockRepo = nil
        super.tearDown()
    }

    func testSignInSuccess() async {
        sut.signIn(email: "test@test.com", password: "password")
        // Wait for async task
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(mockRepo.didSignIn)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testSignInFailure() async {
        mockRepo.shouldThrowError = true
        sut.signIn(email: "test@test.com", password: "password")
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testRegisterSuccess() async {
        sut.register(email: "test@test.com", password: "password")
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(mockRepo.didRegister)
        XCTAssertNil(sut.errorMessage)
    }

    func testSignOutSuccess() {
        sut.signOut()
        XCTAssertTrue(mockRepo.didSignOut)
    }
}
