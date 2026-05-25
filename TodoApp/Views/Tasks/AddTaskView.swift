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
