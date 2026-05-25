import Foundation
import Combine

class MockTaskRepository: TaskRepositoryProtocol {
    var mockedTasks: [TodoItem] = []
    var didAddTask = false
    var didUpdateTask = false
    var didDeleteTask = false
    var shouldThrowError = false

    var fetchSubject = PassthroughSubject<[TodoItem], Error>()

    enum MockError: Error {
        case fetchFailed
        case actionFailed
    }

    func fetchTasks(for userId: String) -> AnyPublisher<[TodoItem], Error> {
        return fetchSubject.eraseToAnyPublisher()
    }

    func addTask(_ item: TodoItem) async throws {
        if shouldThrowError { throw MockError.actionFailed }
        didAddTask = true
        mockedTasks.append(item)
    }

    func updateTask(_ item: TodoItem) async throws {
        if shouldThrowError { throw MockError.actionFailed }
        didUpdateTask = true
        if let index = mockedTasks.firstIndex(where: { $0.id == item.id }) {
            mockedTasks[index] = item
        }
    }

    func deleteTask(_ item: TodoItem) async throws {
        if shouldThrowError { throw MockError.actionFailed }
        didDeleteTask = true
        mockedTasks.removeAll(where: { $0.id == item.id })
    }
}
