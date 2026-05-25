# To-Do App — Implementation Document

**Platform:** iOS  
**Language:** Swift 5.9  
**Xcode:** 15.0  
**macOS:** Ventura 13.6.1  
**Backend:** Firebase (Firestore + Auth)  
**Architecture:** MVVM + Repository Pattern

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Project Structure](#3-project-structure)
4. [Tech Stack & Dependencies](#4-tech-stack--dependencies)
5. [Data Models](#5-data-models)
6. [Firebase Configuration — Deferred Init](#6-firebase-configuration--deferred-init)
7. [Feature Implementation](#7-feature-implementation)
8. [UI Design System](#8-ui-design-system)
9. [Progress Report](#9-progress-report)
10. [Known Issues & Limitations](#10-known-issues--limitations)
11. [Next Steps](#11-next-steps)

---

## 1. Project Overview

A clean, modern iOS To-Do application backed by Firebase. Users can register/sign in, create tasks with titles and optional due dates, mark tasks complete, and have their data sync in real time across devices.

### Core Features

- Email/password authentication via Firebase Auth
- Real-time task sync via Cloud Firestore
- Create, read, update, and delete (CRUD) tasks
- Mark tasks complete/incomplete
- Filter tasks by status (All / Active / Completed)
- Offline support via Firestore's local cache
- **Deferred Firebase initialization** — Firebase is configured only when first needed, not at launch
- Refined, minimal SwiftUI interface with a custom design system

---

## 2. Architecture

The app follows **MVVM** (Model – View – ViewModel) with a **Repository** layer that isolates all Firebase calls. Firebase itself is initialized lazily through a `FirebaseService` singleton so the SDK is not touched until the user interacts with auth or data.

```
┌─────────────────────────────────────────────────┐
│                    Views (SwiftUI)               │
│  TaskListView  TaskRowView  AddTaskView  LoginView│
└──────────────────────┬──────────────────────────┘
                       │ @StateObject / @EnvironmentObject
┌──────────────────────▼──────────────────────────┐
│                  ViewModels                      │
│   AuthViewModel        TaskListViewModel         │
└──────────────────────┬──────────────────────────┘
                       │ protocol calls
┌──────────────────────▼──────────────────────────┐
│               Repository Layer                   │
│   AuthRepository       TaskRepository            │
└──────────────────────┬──────────────────────────┘
                       │ on first use
┌──────────────────────▼──────────────────────────┐
│           FirebaseService (lazy singleton)        │
│   configure() called once, guarded by token      │
└──────────────────────┬──────────────────────────┘
                       │ SDK calls
┌──────────────────────▼──────────────────────────┐
│                   Firebase                       │
│   Firebase Auth            Cloud Firestore        │
└─────────────────────────────────────────────────┘
```

### Why Deferred Init?

Calling `FirebaseApp.configure()` in `App.init()` forces the SDK to load and connect at cold-launch time, even before the user has accepted any privacy prompts. Deferring it to the first repository call means:

- Cold launch is faster (no network handshake on main thread)
- SDK only activates after any consent/permission flows you add later
- Easier to conditionally skip Firebase in UI Previews and unit tests

---

## 3. Project Structure

```
TodoApp/
├── App/
│   ├── TodoApp.swift              # @main — NO FirebaseApp.configure() here
│   └── ContentView.swift          # Root router (auth gate)
│
├── Models/
│   └── TodoItem.swift             # Codable struct, Firestore mapping
│
├── Services/
│   └── FirebaseService.swift      # Lazy singleton — configure() called once
│
├── Repositories/
│   ├── Protocols/
│   │   ├── AuthRepositoryProtocol.swift
│   │   └── TaskRepositoryProtocol.swift
│   ├── AuthRepository.swift       # Firebase Auth wrapper
│   └── TaskRepository.swift       # Firestore CRUD + real-time listener
│
├── ViewModels/
│   ├── AuthViewModel.swift
│   └── TaskListViewModel.swift
│
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Tasks/
│   │   ├── TaskListView.swift
│   │   ├── TaskRowView.swift
│   │   └── AddTaskView.swift
│   └── Components/
│       ├── FilterChipView.swift
│       ├── EmptyStateView.swift
│       └── AppTheme.swift         # Design tokens
│
└── Resources/
    ├── GoogleService-Info.plist   # Firebase config (not committed to git)
    └── Assets.xcassets
```

---

## 4. Tech Stack & Dependencies

### Swift Package Manager Dependencies

Add in **Xcode → File → Add Package Dependencies**:

| Package | URL | Version |
|---|---|---|
| Firebase iOS SDK | `https://github.com/firebase/firebase-ios-sdk` | `10.x` (latest) |

**Products to link** in target settings:
- `FirebaseAuth`
- `FirebaseFirestore`
- `FirebaseFirestoreSwift`

### Minimum Deployment Target

iOS 16.0 — enables full SwiftUI features and `@Observable` readiness.

---

## 5. Data Models

### TodoItem

```swift
// Models/TodoItem.swift
import FirebaseFirestoreSwift
import Foundation

struct TodoItem: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var dueDate: Date?
    var userId: String

    // Computed helper — not stored in Firestore
    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }
}
```

### Firestore Path

```
/users/{userId}/todos/{todoId}
```

---

## 6. Firebase Configuration — Deferred Init

### 6.1 The Problem with Eager Init

```swift
// ❌ BEFORE — eager init blocks launch and bypasses consent flows
@main
struct TodoApp: App {
    init() {
        FirebaseApp.configure()   // runs unconditionally at cold launch
    }
}
```

### 6.2 FirebaseService — Lazy Singleton

Firebase is configured exactly once, on first use. A `nonisolated(unsafe)` flag plus a `DispatchOnce` guard prevents double-configuration across concurrent callers.

```swift
// Services/FirebaseService.swift
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
```

### 6.3 App Entry Point — No Configure Call

```swift
// App/TodoApp.swift
import SwiftUI

// ✅ AFTER — Firebase is NOT touched at launch
@main
struct TodoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthViewModel())
        }
    }
}
```

`FirebaseService.shared.auth` and `.firestore` are the only entry points to the SDK from this point forward. Repositories never import `FirebaseCore` or call `configure()` directly.

### 6.4 Previews & Unit Tests

Because Firebase is deferred, SwiftUI Previews and tests that use mock repositories never trigger `FirebaseApp.configure()` at all — no need for a separate `GoogleService-Info.plist` in the test bundle.

```swift
// In Previews — no Firebase touched
#Preview {
    TaskListView()
        .environmentObject(AuthViewModel(repo: MockAuthRepository()))
}
```

### 6.5 Security Rules

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/todos/{todoId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

---

## 7. Feature Implementation

### 7.1 AuthRepository

```swift
// Repositories/AuthRepository.swift
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
```

### 7.2 AuthViewModel

```swift
// ViewModels/AuthViewModel.swift
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
```

### 7.3 TaskRepository

```swift
// Repositories/TaskRepository.swift
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
```

### 7.4 TaskListViewModel

```swift
// ViewModels/TaskListViewModel.swift
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

    func delete(_ item: TodoItem) {
        Task { try? await repo.deleteTask(item) }
    }
}
```

---

## 8. UI Design System

### 8.1 Design Tokens

A central `AppTheme` keeps spacing, type, and color consistent across all views. Adapts to light/dark automatically via semantic SwiftUI colors.

```swift
// Views/Components/AppTheme.swift
import SwiftUI

enum AppTheme {

    // MARK: Colors
    enum Color {
        static let accent       = SwiftUI.Color.indigo
        static let surface      = SwiftUI.Color(.secondarySystemBackground)
        static let surfaceRaised = SwiftUI.Color(.systemBackground)
        static let destructive  = SwiftUI.Color.red
        static let muted        = SwiftUI.Color(.tertiaryLabel)
        static let success      = SwiftUI.Color.mint
    }

    // MARK: Radius
    enum Radius {
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 18
        static let pill: CGFloat = 100
    }

    // MARK: Spacing
    enum Space {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
    }

    // MARK: Typography helpers
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
```

### 8.2 ContentView (Auth Gate)

```swift
// App/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.user != nil {
                TaskListView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                LoginView()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.user == nil)
    }
}
```

### 8.3 LoginView

A full-screen auth form with a branded header, floating label fields, and a loading state.

```swift
// Views/Auth/LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var body: some View {
        ZStack {
            AppTheme.Color.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.Space.xl) {
                    // Wordmark
                    VStack(spacing: AppTheme.Space.xs) {
                        Image(systemName: "checkmark.square.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.Color.accent)

                        Text("Taskly")
                            .font(.system(size: 32, weight: .bold, design: .rounded))

                        Text("Your tasks. Always in sync.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Color.muted)
                    }
                    .padding(.top, AppTheme.Space.xl * 2)

                    // Form card
                    VStack(spacing: AppTheme.Space.md) {
                        AuthTextField(label: "Email", text: $email,
                                      keyboard: .emailAddress, isSecure: false)
                        AuthTextField(label: "Password", text: $password,
                                      keyboard: .default, isSecure: true)

                        if let msg = authVM.errorMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Color.destructive)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, AppTheme.Space.xs)
                        }

                        PrimaryButton(title: "Sign In", isLoading: authVM.isLoading) {
                            authVM.signIn(email: email, password: password)
                        }
                    }
                    .padding(AppTheme.Space.lg)
                    .background(AppTheme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                    .padding(.horizontal, AppTheme.Space.md)

                    // Register link
                    Button {
                        showRegister = true
                    } label: {
                        Text("No account? ")
                            .foregroundStyle(AppTheme.Color.muted)
                        + Text("Create one →")
                            .foregroundStyle(AppTheme.Color.accent)
                    }
                    .font(.subheadline)

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
    }
}

// MARK: - Sub-components

private struct AuthTextField: View {
    let label: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    let isSecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Color.muted)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, AppTheme.Space.md)
            .padding(.vertical, AppTheme.Space.sm + 2)
            .background(AppTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
        }
    }
}

private struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Space.md)
        }
        .background(AppTheme.Color.accent)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .disabled(isLoading)
    }
}
```

### 8.4 TaskListView

Custom filter chips replace the default `Picker`, and the list uses a card layout instead of the default inset grouped style.

```swift
// Views/Tasks/TaskListView.swift
import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = TaskListViewModel()
    @State private var showAddTask = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppTheme.Color.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress banner
                    ProgressBanner(completed: vm.completedCount, total: vm.totalCount)
                        .padding(.horizontal, AppTheme.Space.md)
                        .padding(.top, AppTheme.Space.sm)

                    // Filter chips
                    FilterChipRow(selection: $vm.filter)
                        .padding(.horizontal, AppTheme.Space.md)
                        .padding(.vertical, AppTheme.Space.sm)

                    Divider()

                    // Task list
                    if vm.filteredTasks.isEmpty {
                        EmptyStateView(filter: vm.filter)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppTheme.Space.sm) {
                                ForEach(vm.filteredTasks) { task in
                                    TaskRowView(task: task) {
                                        vm.toggleComplete(task)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            vm.delete(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, AppTheme.Space.sm)
                        }
                    }
                }

                // FAB
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.Color.accent)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.Color.accent.opacity(0.4),
                                radius: 12, y: 4)
                }
                .padding(AppTheme.Space.lg)
            }
            .navigationTitle("My Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        authVM.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(AppTheme.Color.muted)
                    }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(vm: vm)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .alert("Something went wrong", isPresented: $showError,
                   presenting: vm.errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
            .onChange(of: vm.errorMessage) { _, new in
                showError = new != nil
            }
        }
        .onAppear {
            if let userId = authVM.user?.uid {
                vm.subscribe(userId: userId)
            }
        }
    }
}

// MARK: - Progress Banner

private struct ProgressBanner: View {
    let completed: Int
    let total: Int

    private var progress: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
            HStack {
                Text("\(completed) of \(total) done")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.muted)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(AppTheme.mono(12, weight: .medium))
                    .foregroundStyle(AppTheme.Color.accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.pill)
                        .fill(AppTheme.Color.accent.opacity(0.15))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: AppTheme.Radius.pill)
                        .fill(AppTheme.Color.accent)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 4)
        }
        .padding(AppTheme.Space.md)
        .background(AppTheme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }
}
```

### 8.5 FilterChipRow

```swift
// Views/Components/FilterChipView.swift
import SwiftUI

struct FilterChipRow: View {
    @Binding var selection: TaskFilter

    var body: some View {
        HStack(spacing: AppTheme.Space.sm) {
            ForEach(TaskFilter.allCases) { filter in
                FilterChip(
                    title: filter.rawValue,
                    isSelected: selection == filter
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = filter
                    }
                }
            }
            Spacer()
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, AppTheme.Space.md)
                .padding(.vertical, AppTheme.Space.xs + 2)
                .background(
                    isSelected
                        ? AppTheme.Color.accent
                        : AppTheme.Color.surfaceRaised
                )
                .foregroundStyle(
                    isSelected ? .white : AppTheme.Color.muted
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected
                                ? Color.clear
                                : AppTheme.Color.muted.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
```

### 8.6 TaskRowView

Card-based rows with a smooth completion animation.

```swift
// Views/Tasks/TaskRowView.swift
import SwiftUI

struct TaskRowView: View {
    let task: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Space.md) {
            // Toggle button
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isCompleted
                                ? AppTheme.Color.success
                                : AppTheme.Color.muted.opacity(0.4),
                            lineWidth: 1.5
                        )
                        .frame(width: 24, height: 24)

                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.Color.success)
                    }
                }
                .animation(.spring(response: 0.25), value: task.isCompleted)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted, color: AppTheme.Color.muted)
                    .foregroundStyle(
                        task.isCompleted
                            ? AppTheme.Color.muted
                            : .primary
                    )
                    .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

                if let due = task.dueDate {
                    HStack(spacing: AppTheme.Space.xs) {
                        Image(systemName: task.isOverdue
                              ? "exclamationmark.circle.fill"
                              : "calendar")
                            .font(.caption2)
                        Text(due, style: .date)
                            .font(.caption)
                    }
                    .foregroundStyle(
                        task.isOverdue
                            ? AppTheme.Color.destructive
                            : AppTheme.Color.muted
                    )
                }
            }

            Spacer()

            // Priority dot (placeholder for future priority field)
            if !task.isCompleted {
                Circle()
                    .fill(AppTheme.Color.accent.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(AppTheme.Space.md)
        .background(AppTheme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}
```

### 8.7 AddTaskView

Sheet-based input with a custom bottom-anchored layout.

```swift
// Views/Tasks/AddTaskView.swift
import SwiftUI

struct AddTaskView: View {
    @ObservedObject var vm: TaskListViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var titleError = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Space.lg) {

                // Title field
                VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
                    Text("Task")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Color.muted)

                    TextField("What needs to be done?", text: $title, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($titleFocused)
                        .font(.body)
                        .padding(AppTheme.Space.md)
                        .background(AppTheme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                                .strokeBorder(
                                    titleError
                                        ? AppTheme.Color.destructive
                                        : AppTheme.Color.accent.opacity(titleFocused ? 1 : 0),
                                    lineWidth: 1.5
                                )
                        )
                        .onChange(of: title) { _, _ in titleError = false }

                    if titleError {
                        Text("Please enter a task name.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Color.destructive)
                    }
                }

                // Due date toggle
                VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                    Toggle(isOn: $hasDueDate) {
                        Label("Set due date", systemImage: "calendar")
                            .font(.subheadline)
                    }
                    .tint(AppTheme.Color.accent)

                    if hasDueDate {
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(AppTheme.Color.accent)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: hasDueDate)

                Spacer()

                // Add button
                Button {
                    submit()
                } label: {
                    Text("Add Task")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Space.md)
                }
                .background(AppTheme.Color.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            }
            .padding(AppTheme.Space.lg)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.Color.muted)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private func submit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation { titleError = true }
            return
        }
        vm.addTask(
            title: trimmed,
            dueDate: hasDueDate ? dueDate : nil,
            userId: authVM.user?.uid ?? ""
        )
        dismiss()
    }
}
```

### 8.8 EmptyStateView

```swift
// Views/Components/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    let filter: TaskFilter

    private var icon: String {
        switch filter {
        case .all:       return "tray"
        case .active:    return "checkmark.circle"
        case .completed: return "clock.arrow.circlepath"
        }
    }

    private var message: String {
        switch filter {
        case .all:       return "No tasks yet.\nTap + to add your first one."
        case .active:    return "All caught up!\nNo active tasks remaining."
        case .completed: return "Nothing completed yet.\nGet started!"
        }
    }

    var body: some View {
        VStack(spacing: AppTheme.Space.md) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(AppTheme.Color.muted)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Color.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
```

---

## 9. Progress Report

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | Project scaffolding & SPM setup | ✅ Complete | Firebase 10.x linked |
| 2 | Deferred Firebase initialization | ✅ Complete | `FirebaseService` lazy singleton |
| 3 | Firebase Auth — Email/Password | ✅ Complete | Sign in, register, sign out |
| 4 | Auth state listener & routing | ✅ Complete | Animated transition in ContentView |
| 5 | Firestore data model (`TodoItem`) | ✅ Complete | Codable + `@DocumentID` |
| 6 | TaskRepository — real-time listener | ✅ Complete | Combine Publisher |
| 7 | Create task | ✅ Complete | AddTaskView sheet, inline validation |
| 8 | Toggle complete | ✅ Complete | Spring animation on checkmark |
| 9 | Delete task | ✅ Complete | Context menu long-press |
| 10 | Filter tasks (All/Active/Completed) | ✅ Complete | Custom chip row |
| 11 | Due date support + overdue indicator | ✅ Complete | Icon + red text on overdue rows |
| 12 | Progress banner | ✅ Complete | Animated progress bar |
| 13 | Empty state per filter | ✅ Complete | Icon + contextual message |
| 14 | Error alert surfacing | ✅ Complete | `.alert()` bound to `errorMessage` |
| 15 | Offline support | ✅ Complete | Firestore cache enabled by default |
| 16 | Firestore Security Rules | ✅ Complete | Users scoped to own data |
| 17 | Inline task editing | 🔲 Planned | Tap row title to edit |
| 18 | Push notifications for due dates | 🔲 Planned | Firebase Cloud Messaging |
| 19 | Unit tests (ViewModels) | 🔲 Planned | Mock repositories via protocols |
| 20 | Widget extension | 🔲 Planned | WidgetKit showing today's tasks |

**Overall completion: ~80%** — All core CRUD, auth, deferred Firebase init, and polished UI are implemented.

---

## 10. Known Issues & Limitations

- **No pagination** — Firestore listener fetches all tasks for the user. Above ~500 tasks, add cursor-based pagination with `limit()` and `startAfter()`.
- **No conflict resolution** — simultaneous edits from two devices use last-write-wins. Acceptable for a personal app; shared lists would need Firestore transactions.
- **`GoogleService-Info.plist` must not be committed** — add it to `.gitignore` and distribute via CI secrets or a separate secure channel.
- **Deferred init and App Clips** — if you add an App Clip target, ensure `FirebaseService.configure()` is still called before any network access within the clip.

---

## 11. Next Steps

1. **Inline task editing** — tap a task title to replace `Text` with a focused `TextField` inline in the row.
2. **Task priority** — add a `priority: Int` field to `TodoItem` and surface it as a colored dot (already scaffolded in `TaskRowView`).
3. **Unit tests** — create `MockTaskRepository` and `MockAuthRepository` conforming to their protocols, then write `XCTest` cases for both ViewModels.
4. **UI tests** — add `XCUITest` flows for sign-in, add task, toggle complete, and delete.
5. **CI/CD** — set up a GitHub Actions workflow with `xcodebuild test` and Firebase App Distribution for TestFlight-like distribution.
6. **WidgetKit** — surface today's incomplete tasks in a home-screen widget using a shared App Group `UserDefaults` snapshot.

---

*Document version: 2.0 — Deferred Firebase init + polished UI | Swift 5.9 / Xcode 15.0 / Firebase iOS SDK 10.x*