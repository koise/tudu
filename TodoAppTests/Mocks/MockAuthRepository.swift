import Foundation
import FirebaseAuth

class MockAuthRepository: AuthRepositoryProtocol {
    var currentUser: User? = nil
    var didSignIn = false
    var didRegister = false
    var didSignOut = false
    var shouldThrowError = false

    enum MockError: Error {
        case someError
    }

    func signIn(email: String, password: String) async throws {
        if shouldThrowError { throw MockError.someError }
        didSignIn = true
    }

    func register(email: String, password: String) async throws {
        if shouldThrowError { throw MockError.someError }
        didRegister = true
    }

    func signOut() throws {
        if shouldThrowError { throw MockError.someError }
        didSignOut = true
    }
}
