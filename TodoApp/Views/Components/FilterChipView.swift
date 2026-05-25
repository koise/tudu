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
