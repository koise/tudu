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
