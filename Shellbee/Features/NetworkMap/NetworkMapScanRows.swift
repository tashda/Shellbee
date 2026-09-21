import SwiftUI

/// A small inset-grouped list, styled like a Settings section, used for the
/// figures on the network-scan card.
struct NetworkMapScanRows<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            if #available(iOS 18.0, *) {
                SwiftUI.Group(subviews: content) { rows in
                    ForEach(rows.indices, id: \.self) { index in
                        if index > rows.startIndex {
                            Divider().padding(.leading, DesignTokens.Spacing.md)
                        }
                        rows[index]
                    }
                }
            } else {
                content
            }
        }
        .background(
            Color(.tertiarySystemFill),
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous)
        )
    }
}

/// One label/value line in `NetworkMapScanRows`.
struct NetworkMapScanRow: View {
    let label: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack {
            Text(label)
            Spacer(minLength: DesignTokens.Spacing.md)
            Text(value)
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.subheadline)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}
