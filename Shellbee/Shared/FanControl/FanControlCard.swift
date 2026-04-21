import SwiftUI

struct FanControlCard: View {
    let context: FanControlContext
    let mode: CardDisplayMode
    let onSend: (JSONValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            header
            if let modes = context.fanModeFeature?.values, !modes.isEmpty { modeControl(modes: modes) }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if mode == .snapshot {
                Image(systemName: context.isOn ? "fan.fill" : "fan")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(context.isOn ? Color.teal : Color(.tertiaryLabel))
                Text("Fan State").font(.headline)
            } else {
                Text("Fan").font(.headline)
            }
            Spacer()
            if mode == .interactive, let f = context.stateFeature, f.isWritable {
                Toggle("", isOn: Binding(
                    get: { context.isOn },
                    set: { _ in if let p = context.togglePayload() { onSend(p) } }
                ))
                .labelsHidden()
            } else {
                stateBadge
            }
        }
    }

    private var stateBadge: some View {
        Text(context.isOn ? "ON" : "OFF")
            .font(.caption.weight(.bold))
            .foregroundStyle(context.isOn ? Color.teal : Color(.secondaryLabel))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                context.isOn ? Color.teal.opacity(DesignTokens.Opacity.chipFill) : Color(.tertiarySystemFill),
                in: Capsule()
            )
    }

    private func modeControl(modes: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(modes, id: \.self) { m in
                    let isSelected = context.fanMode == m
                    Button {
                        if mode == .interactive, let p = context.fanModePayload(m) { onSend(p) }
                    } label: {
                        Text(m.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .background(isSelected ? Color.teal : Color(.tertiarySystemFill), in: Capsule())
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(mode == .snapshot)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            if let ctx = FanControlContext(device: .preview, state: [
                "state": .string("ON"), "fan_mode": .string("medium")
            ]) {
                FanControlCard(context: ctx, mode: .interactive, onSend: { _ in })
                FanControlCard(context: ctx, mode: .snapshot, onSend: { _ in })
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
