import SwiftUI

/// One fact under the identity hero, like a tile in Contacts' action row:
/// a symbol, a value and what it is ("149 · Signal").
struct IdentityTile: Identifiable {
    let value: String
    let caption: String
    var systemImage: String? = nil
    var symbolVariableValue: Double? = nil
    /// Draws a status dot in place of the symbol.
    var dotColor: Color? = nil
    /// Colour for the value and symbol; leave nil unless it needs attention.
    var color: Color? = nil

    var id: String { caption }
}

/// Header for Device and Group detail: the image centred above the name and
/// a readable description, then up to four tiles for the facts people check
/// (status, signal, power, role). When several bridges are saved, the bridge
/// sits under the description with its monogram.
struct IdentityHero<Artwork: View>: View {
    let name: String
    let subtitle: String
    var bridgeID: UUID? = nil
    var bridgeName: String? = nil
    let tiles: [IdentityTile]
    var renameAccessibilityLabel: String = "Rename"
    var onRenameTapped: (() -> Void)? = nil
    /// Reports whether the name has scrolled under the navigation bar, so
    /// the screen can show its title only then.
    var onNameHiddenChange: ((Bool) -> Void)? = nil
    @ViewBuilder let artwork: () -> Artwork

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                artwork()
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
                    BridgeAttributionLine(bridgeID: bridgeID, bridgeName: bridgeName)
                }
            }

            if !tiles.isEmpty {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(tiles) { IdentityTileView(tile: $0) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.xs)
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

private struct IdentityTileView: View {
    let tile: IdentityTile

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            symbol
                .frame(height: DesignTokens.Size.identityTileSymbol)
            Text(tile.value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tile.color.map { AnyShapeStyle(.themedStatus($0)) } ?? AnyShapeStyle(.primary))
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMedium)
            Text(tile.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .background(.shellbeeSurface, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tile.caption): \(tile.value)")
    }

    @ViewBuilder
    private var symbol: some View {
        if let dotColor = tile.dotColor {
            Circle()
                .fill(.themedStatus(dotColor))
                .frame(width: DesignTokens.Size.statusDotHero, height: DesignTokens.Size.statusDotHero)
        } else if let systemImage = tile.systemImage {
            Image(systemName: systemImage, variableValue: tile.symbolVariableValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tile.color.map { AnyShapeStyle(.themedStatus($0)) } ?? AnyShapeStyle(.secondary))
        }
    }
}

#Preview {
    List {
        IdentityHero(
            name: "bathroom_ff_spot_1",
            subtitle: "Philips · Hue White and Colour Ambiance GU10",
            tiles: [
                IdentityTile(value: "Online", caption: "Seen 2 min ago", dotColor: .green),
                IdentityTile(value: "128", caption: "Signal", systemImage: "cellularbars", symbolVariableValue: 0.5),
                IdentityTile(value: "Mains", caption: "Power", systemImage: "powerplug"),
                IdentityTile(value: "Router", caption: "Role", systemImage: "point.3.connected.trianglepath.dotted"),
            ]
        ) {
            Image(systemName: "lightbulb.fill").font(.largeTitle)
        }
        .listRowBackground(Color.clear)
    }
    .environment(AppEnvironment())
}
