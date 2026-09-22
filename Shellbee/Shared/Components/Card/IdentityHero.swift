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

/// Centred header for Device and Group detail, like the top of an AirPods
/// or Apple Watch page in Settings: a large image, the name, a readable
/// description and a row of neutral status capsules. No card behind it.
struct IdentityHero<Artwork: View>: View {
    let name: String
    let subtitle: String
    var bridgeID: UUID? = nil
    var bridgeName: String? = nil
    let chips: [IdentityChip]
    var footnote: String? = nil
    var renameAccessibilityLabel: String = "Rename"
    var onRenameTapped: (() -> Void)? = nil
    /// Reports whether the name has scrolled under the navigation bar, so
    /// the screen can show its title only then.
    var onNameHiddenChange: ((Bool) -> Void)? = nil
    @ViewBuilder let artwork: () -> Artwork

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            artwork()
                .padding(.bottom, DesignTokens.Spacing.sm)

            nameView
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.frame(in: .scrollView).maxY < 0
                } action: { hidden in
                    onNameHiddenChange?(hidden)
                }

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let bridgeID, let bridgeName, !bridgeName.isEmpty {
                BridgeAttributionBadge(bridgeID: bridgeID, bridgeName: bridgeName)
                    .padding(.top, DesignTokens.Spacing.xxs)
            }

            if !chips.isEmpty {
                FlowChips(chips: chips)
                    .padding(.top, DesignTokens.Spacing.sm)
            }

            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, DesignTokens.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    @ViewBuilder
    private var nameView: some View {
        let label = Text(name)
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
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

/// Status capsules that wrap onto a second line when they don't fit.
private struct FlowChips: View {
    let chips: [IdentityChip]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.Spacing.sm) { chipViews }
            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.sm) { chipViews(chips.prefix(2)) }
                HStack(spacing: DesignTokens.Spacing.sm) { chipViews(chips.dropFirst(2)) }
            }
        }
    }

    private var chipViews: some View { chipViews(chips[...]) }

    private func chipViews(_ slice: ArraySlice<IdentityChip>) -> some View {
        ForEach(Array(slice)) { chip in
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let dotColor = chip.dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: DesignTokens.Size.statusDotHero, height: DesignTokens.Size.statusDotHero)
                }
                if let systemImage = chip.systemImage {
                    Image(systemName: systemImage, variableValue: chip.symbolVariableValue)
                        .font(.caption.weight(.semibold))
                }
                Text(chip.title)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .foregroundStyle(chip.color ?? .primary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs + DesignTokens.Spacing.xxs)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .accessibilityElement(children: .combine)
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
            ],
            footnote: "Last seen 4 min ago"
        ) {
            Image(systemName: "lightbulb.fill").font(.largeTitle)
        }
        .listRowBackground(Color.clear)
    }
}
