import SwiftUI

struct NetworkMapFilterBar: View {
    @Binding var filters: Set<NetworkMapFilter>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(NetworkMapFilter.allCases) { filter in
                    FilterChip(
                        label: filter.rawValue,
                        systemImage: filter.systemImage,
                        isSelected: filters.contains(filter)
                    ) {
                        if filters.contains(filter) {
                            filters.remove(filter)
                        } else {
                            filters.insert(filter)
                        }
                    }
                }
                if !filters.isEmpty {
                    Button("Clear") { filters.removeAll() }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .accessibilityLabel("Network Map Filters")
    }
}
