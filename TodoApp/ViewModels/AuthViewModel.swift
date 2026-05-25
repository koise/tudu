import SwiftUI
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let repo: AuthRepositoryProtocol
    private var handle: AuthStateDidChangeListenerHandle?

    init(repo: AuthRepositoryProtocol = AuthRepository()) {
        self.repo = repo
        // Accessing .auth here triggers deferred configure()
        handle = FirebaseService.shared.auth.addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    func signIn(email: String, password: String) {
        run { try await self.repo.signIn(email: email, password: password) }
    }

    func register(email: String, password: String) {
        run { try await self.repo.register(email: email, password: password) }
    }

    func signOut() {
        try? repo.signOut()
    }

    // MARK: - Private

    private func run(_ action: @escaping () async throws -> Void) {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                try await action()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    deinit {
        if let handle {
            FirebaseService.shared.auth.removeStateDidChangeListener(handle)
        }
    }
}
