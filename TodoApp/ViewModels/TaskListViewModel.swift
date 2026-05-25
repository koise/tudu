import SwiftUI
import Combine

enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
    var id: String { rawValue }
}

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published var tasks: [TodoItem] = []
    @Published var filter: TaskFilter = .all
    @Published var errorMessage: String?

    var filteredTasks: [TodoItem] {
        switch filter {
        case .all:       return tasks
        case .active:    return tasks.filter { !$0.isCompleted }
        case .completed: return tasks.filter { $0.isCompleted }
        }
    }

    var completedCount: Int { tasks.filter { $0.isCompleted }.count }
    var totalCount: Int { tasks.count }

    private let repo: TaskRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    init(repo: TaskRepositoryProtocol = TaskRepository()) {
        self.repo = repo
    }

    func subscribe(userId: String) {
        repo.fetchTasks(for: userId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] items in
                    self?.tasks = items
                }
            )
            .store(in: &cancellables)
    }

    func addTask(title: String, dueDate: Date?, userId: String) {
        let item = TodoItem(
            title: title,
            isCompleted: false,
            createdAt: Date(),
            dueDate: dueDate,
            userId: userId
        )
        Task { try? await repo.addTask(item) }
    }

    func toggleComplete(_ item: TodoItem) {
        var updated = item
        updated.isCompleted.toggle()
        Task { try? await repo.updateTask(updated) }
    }

    func update(_ item: TodoItem) async throws {
        try await repo.updateTask(item)
    }

    func delete(_ item: TodoItem) {
        Task { try? await repo.deleteTask(item) }
    }
}
