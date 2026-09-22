import SwiftUI

/// A stable trailing slot for settings-style single selection rows.
///
/// The slot remains in the layout when it is empty, so values never shift
/// horizontally when a row gains or loses its checkmark.
struct SelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: DesignTokens.Size.selectionIndicatorColumn, alignment: .trailing)
    }
}

#Preview {
    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.sm) {
        SelectionIndicator(isSelected: false)
        SelectionIndicator(isSelected: true)
    }
    .padding()
}
