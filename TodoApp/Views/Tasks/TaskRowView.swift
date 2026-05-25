import SwiftUI

struct TaskRowView: View {
    let task: TodoItem
    let onToggle: () -> Void
    var onUpdateTitle: ((String) -> Void)? = nil

    @State private var isEditing = false
    @State private var editTitle = ""
    @FocusState private var isFocused: Bool

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
                if isEditing {
                    TextField("Task title", text: $editTitle)
                        .font(.body)
                        .focused($isFocused)
                        .onSubmit { finishEditing() }
                } else {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted, color: AppTheme.Color.muted)
                        .foregroundStyle(
                            task.isCompleted
                                ? AppTheme.Color.muted
                                : .primary
                        )
                        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
                        .onTapGesture {
                            startEditing()
                        }
                }

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

            // Priority dot
            if !task.isCompleted && task.priority > 0 {
                Circle()
                    .fill(task.priority == 1 ? AppTheme.Color.destructive : AppTheme.Color.accent.opacity(0.5))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(AppTheme.Space.md)
        .background(AppTheme.Color.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .onChange(of: isFocused) { _, newValue in
            if !newValue && isEditing {
                finishEditing()
            }
        }
    }

    private func startEditing() {
        guard !task.isCompleted else { return }
        editTitle = task.title
        isEditing = true
        isFocused = true
    }

    private func finishEditing() {
        guard isEditing else { return }
        isEditing = false
        if !editTitle.trimmingCharacters(in: .whitespaces).isEmpty && editTitle != task.title {
            onUpdateTitle?(editTitle)
        }
    }
}
