import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

protocol TaskRepositoryProtocol {
    func fetchTasks(for userId: String) -> AnyPublisher<[TodoItem], Error>
    func addTask(_ item: TodoItem) async throws
    func updateTask(_ item: TodoItem) async throws
    func deleteTask(_ item: TodoItem) async throws
}

final class TaskRepository: TaskRepositoryProtocol {
    // Accessing .firestore here triggers deferred configure()
    private var db: Firestore { FirebaseService.shared.firestore }

    private func collection(for userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("todos")
    }

    func fetchTasks(for userId: String) -> AnyPublisher<[TodoItem], Error> {
        let subject = PassthroughSubject<[TodoItem], Error>()
        let listener = collection(for: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    subject.send(completion: .failure(error))
                    return
                }
                let items = snapshot?.documents.compactMap {
                    try? $0.data(as: TodoItem.self)
                } ?? []
                subject.send(items)
            }
        return subject
            .handleEvents(receiveCancel: { listener.remove() })
            .eraseToAnyPublisher()
    }

    func addTask(_ item: TodoItem) async throws {
        _ = try collection(for: item.userId).addDocument(from: item)
    }

    func updateTask(_ item: TodoItem) async throws {
        guard let id = item.id else { return }
        try collection(for: item.userId).document(id).setData(from: item)
    }

    func deleteTask(_ item: TodoItem) async throws {
        guard let id = item.id else { return }
        try await collection(for: item.userId).document(id).delete()
    }
}
