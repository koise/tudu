import XCTest
import Combine

@MainActor
final class TaskListViewModelTests: XCTestCase {

    var sut: TaskListViewModel!
    var mockRepo: MockTaskRepository!

    override func setUp() {
        super.setUp()
        mockRepo = MockTaskRepository()
        sut = TaskListViewModel(repo: mockRepo)
    }

    override func tearDown() {
        sut = nil
        mockRepo = nil
        super.tearDown()
    }

    func testAddTaskSuccess() async {
        sut.addTask(title: "New Task", dueDate: nil, userId: "user123")
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(mockRepo.didAddTask)
        XCTAssertEqual(mockRepo.mockedTasks.count, 1)
        XCTAssertEqual(mockRepo.mockedTasks.first?.title, "New Task")
    }

    func testToggleCompleteSuccess() async {
        let task = TodoItem(id: "1", title: "Test", isCompleted: false, createdAt: Date(), dueDate: nil, userId: "user", priority: 0)
        mockRepo.mockedTasks = [task]
        
        sut.toggleComplete(task)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(mockRepo.didUpdateTask)
    }
    
    func testDeleteSuccess() async {
        let task = TodoItem(id: "1", title: "Test", isCompleted: false, createdAt: Date(), dueDate: nil, userId: "user", priority: 0)
        mockRepo.mockedTasks = [task]
        
        sut.delete(task)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(mockRepo.didDeleteTask)
        XCTAssertTrue(mockRepo.mockedTasks.isEmpty)
    }
    
    func testFilterLogic() {
        let task1 = TodoItem(id: "1", title: "Test 1", isCompleted: false, createdAt: Date(), dueDate: nil, userId: "user", priority: 0)
        let task2 = TodoItem(id: "2", title: "Test 2", isCompleted: true, createdAt: Date(), dueDate: nil, userId: "user", priority: 0)
        
        sut.tasks = [task1, task2]
        
        sut.filter = .all
        XCTAssertEqual(sut.filteredTasks.count, 2)
        
        sut.filter = .active
        XCTAssertEqual(sut.filteredTasks.count, 1)
        XCTAssertEqual(sut.filteredTasks.first?.id, "1")
        
        sut.filter = .completed
        XCTAssertEqual(sut.filteredTasks.count, 1)
        XCTAssertEqual(sut.filteredTasks.first?.id, "2")
    }
}
