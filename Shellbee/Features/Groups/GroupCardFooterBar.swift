import SwiftUI

struct GroupCardFooterBar: View {
    let group: Group
    let state: [String: JSONValue]

    var body: some View {
        HStack(spacing: 0) {
            statCell(value: "\(group.members.count)", label: "Members", color: .indigo)
            statCell(value: scenesTitle, label: "Scenes", color: .purple)
            statCell(value: stateTitle, label: "State", color: stateColor)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(footerBackground)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: DesignTokens.Spacing.summaryRowVerticalPadding) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var scenesTitle: String {
        group.scenes.isEmpty ? "—" : "\(group.scenes.count)"
    }

    private var stateTitle: String {
        guard let value = state["state"]?.stringValue else { return "—" }
        return value.uppercased()
    }

    private var stateColor: Color {
        guard let value = state["state"]?.stringValue else { return .secondary }
        return value.uppercased() == "ON" ? .green : .red
    }

    private var footerBackground: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separator).opacity(DesignTokens.Opacity.subtleFill))
                .frame(height: DesignTokens.Size.footerTopRule)
            Rectangle()
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }
}

#Preview {
    VStack {
        GroupCardFooterBar(group: .preview, state: ["state": .string("ON")])
        GroupCardFooterBar(group: .previewWithMembers, state: [:])
    }
    .background(Color(.secondarySystemGroupedBackground))
}
