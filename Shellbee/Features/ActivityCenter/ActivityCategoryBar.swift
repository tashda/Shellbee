import SwiftUI

/// Category picker in the style of Mail's categories: the selected
/// category shows its name, the others show only their symbol.
struct ActivityCategoryBar: View {
    @Binding var selection: ActivityScope

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(ActivityScope.allCases) { scope in
                button(for: scope)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func button(for scope: ActivityScope) -> some View {
        let isSelected = scope == selection
        let button = Button {
            withAnimation(.smooth) { selection = scope }
        } label: {
            if isSelected {
                Label(scope.title, systemImage: scope.systemImage)
                    .labelStyle(.titleAndIcon)
            } else {
                Label(scope.title, systemImage: scope.systemImage)
                    .labelStyle(.iconOnly)
            }
        }
        .font(.subheadline.weight(.semibold))
        .accessibilityLabel(scope.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])

        if isSelected {
            button.glassProminentButtonStyleIfAvailable()
        } else {
            button.glassButtonStyleIfAvailable()
        }
    }
}
