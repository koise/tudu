import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import OSLog

/// Single access point to the Firebase SDK.
/// `configure()` is safe to call multiple times — it is a no-op after the first call.
final class FirebaseService {

    static let shared = FirebaseService()
    private init() {}

    private var isConfigured = false
    private let lock = NSLock()
    private let logger = Logger(subsystem: "com.yourname.todoapp", category: "Firebase")

    /// Call this before any Auth or Firestore access.
    /// Idempotent — repeated calls are ignored.
    func configure() {
        lock.lock()
        defer { lock.unlock() }
        guard !isConfigured else { return }
        FirebaseApp.configure()
        isConfigured = true
        logger.info("FirebaseApp configured (deferred).")
    }

    var auth: Auth {
        configure()
        return Auth.auth()
    }

    var firestore: Firestore {
        configure()
        return Firestore.firestore()
    }
}
