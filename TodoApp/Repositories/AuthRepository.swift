import FirebaseAuth

protocol AuthRepositoryProtocol {
    var currentUser: User? { get }
    func signIn(email: String, password: String) async throws
    func register(email: String, password: String) async throws
    func signOut() throws
}

final class AuthRepository: AuthRepositoryProtocol {
    private var firebase: FirebaseService { .shared }

    var currentUser: User? { firebase.auth.currentUser }

    func signIn(email: String, password: String) async throws {
        try await firebase.auth.signIn(withEmail: email, password: password)
    }

    func register(email: String, password: String) async throws {
        try await firebase.auth.createUser(withEmail: email, password: password)
    }

    func signOut() throws {
        try firebase.auth.signOut()
    }
}
