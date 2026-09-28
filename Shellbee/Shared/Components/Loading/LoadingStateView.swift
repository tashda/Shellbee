import SwiftUI

/// A centred "Loading devices" with a spinner, for screens whose content
/// isn't a list of rows (grids, maps, detail panes). Lists use
/// `LoadingPlaceholderRows` instead.
struct LoadingStateView: View {
    let title: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
