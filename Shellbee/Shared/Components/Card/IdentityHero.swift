import SwiftUI

/// One neutral status capsule under the identity hero ("● Online", "Router").
struct IdentityChip: Identifiable {
    let title: String
    var dotColor: Color? = nil
    var systemImage: String? = nil
    var symbolVariableValue: Double? = nil
    /// Colour for the text; leave nil unless the value needs attention.
    var color: Color? = nil

    var id: String { title + (systemImage ?? "") }
}

/// Header for Device and Group detail, like the top of a contact or Apple
/// Account page: the image on the left, the name and a readable
/// description beside it, and one line of neutral status capsules below.
/// When several bridges are saved, the last capsule names the bridge with
/// its monogram.
struct IdentityHero<Artwork: View>: View {
    let name: String
    let subtitle: String
    var bridgeID: UUID? = nil
    var bridgeName: String? = nil
    let chips: [IdentityChip]
    var renameAccessibilityLabel: String = "Rename"
    var onRenameTapped: (() -> Void)? = nil
    /// Reports whether the name has scrolled under the navigation bar, so
    /// the screen can show its title only then.
    var onNameHiddenChange: ((Bool) -> Void)? = nil
    @ViewBuilder let artwork: () -> Artwork

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                artwork()
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    nameView
                        .onGeometryChange(for: Bool.self) { proxy in
                            proxy.frame(in: .scrollView).maxY < 0
                        } action: { hidden in
                            onNameHiddenChange?(hidden)
                        }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !chips.isEmpty || bridgeChip != nil {
                FlowChips(chips: chips, bridge: bridgeChip)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Spacing.xs)
    }

    private var bridgeChip: FlowChips.Bridge? {
        guard let bridgeID, let bridgeName, !bridgeName.isEmpty else { return nil }
        return FlowChips.Bridge(id: bridgeID, name: bridgeName)
    }

    @ViewBuilder
    private var nameView: some View {
        let label = Text(name)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .minimumScaleFactor(DesignTokens.Typography.scaleFactorMedium)

        if let onRenameTapped {
            Button(action: onRenameTapped) {
                label.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(renameAccessibilityLabel)
            .accessibilityValue(name)
        } else {
            label
        }
    }
}

/// Status capsules on one line; they scroll sideways rather than wrap.
private struct FlowChips: View {
    struct Bridge {
        let id: UUID
        let name: String
    }

    let chips: [IdentityChip]
    var bridge: Bridge? = nil

    @Environment(AppEnvironment.self) private var environment
    @AppStorage(BridgeGradientMode.storageKey) private var indicatorModeRaw = BridgeGradientMode.default.rawValue

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.Spacing.xs) { chipViews }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.xs) { chipViews }
            }
        }
    }

    @ViewBuilder
    private var chipViews: some View {
        ForEach(chips) { chip in
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let dotColor = chip.dotColor {
                    Circle()
                        .fill(.themedStatus(dotColor))
                        .frame(width: DesignTokens.Size.statusDotHero, height: DesignTokens.Size.statusDotHero)
                }
                if let systemImage = chip.systemImage {
                    Image(systemName: systemImage, variableValue: chip.symbolVariableValue)
                        .font(.caption.weight(.semibold))
                }
                Text(chip.title)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .foregroundStyle(chip.color ?? .primary)
            .padding(.horizontal, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(.shellbeeSurface, in: Capsule())
            .accessibilityElement(children: .combine)
        }
        if let bridge, BridgeGradientMode.stored(indicatorModeRaw).showsIndicators(in: environment) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                BridgeMonogram(bridgeID: bridge.id, bridgeName: bridge.name)
                Text(bridge.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.leading, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
            .padding(.trailing, DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(.shellbeeSurface, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bridge: \(bridge.name)")
        }
    }
}

#Preview {
    List {
        IdentityHero(
            name: "bathroom_ff_spot_1",
            subtitle: "Philips · Hue White and Colour Ambiance GU10",
            chips: [
                IdentityChip(title: "Online", dotColor: .green),
                IdentityChip(title: "Router"),
                IdentityChip(title: "128", systemImage: "cellularbars", symbolVariableValue: 0.8),
                IdentityChip(title: "Mains"),
            ]
        ) {
            Image(systemName: "lightbulb.fill").font(.largeTitle)
        }
        .listRowBackground(Color.clear)
    }
    .environment(AppEnvironment())
}
