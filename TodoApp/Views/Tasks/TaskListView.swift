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
                                    } onUpdateTitle: { newTitle in
                                        var updated = task
                                        updated.title = newTitle
                                        Task { try? await vm.update(updated) }
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
