import FirebaseFirestoreSwift
import Foundation

struct TodoItem: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var userId: String
    var priority: Int = 0 // 0: Normal, 1: High, 2: Low

    // Computed helper — not stored in Firestore
    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }
}
