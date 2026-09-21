import SwiftUI

/// Horizontally scrolling filter bubbles above the results. A bubble only
/// appears when its category has matches, so the bar never offers a filter
/// that would show an empty list. The selected bubble always stays visible.
struct GlobalSearchScopeBar: View {
    @Binding var selection: GlobalSearchScope
    let results: GlobalSearchResults

    private var visibleScopes: [GlobalSearchScope] {
        GlobalSearchScope.allCases.filter { scope in
            scope == .all || scope == selection || results.count(for: scope) > 0
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(visibleScopes) { scope in
                    bubble(for: scope)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .animation(.snappy, value: visibleScopes)
    }

    private func bubble(for scope: GlobalSearchScope) -> some View {
        let isSelected = selection == scope
        let count = results.count(for: scope)
        return Button {
            selection = scope
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: scope.systemImage)
                    .imageScale(.small)
                Text(scope.title)
                Text(count, format: .number)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(DesignTokens.Opacity.secondaryText)) : AnyShapeStyle(.secondary))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(scope.tint))
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background {
                Capsule().fill(isSelected ? AnyShapeStyle(scope.tint) : AnyShapeStyle(scope.tint.opacity(DesignTokens.Opacity.chipFill)))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(scope.title), \(count) results")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
