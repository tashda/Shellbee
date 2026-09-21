import SwiftUI

/// Leading visual for an Activity card. Devices and groups show their real
/// product image; other events show a symbol at one of three emphasis
/// tiers. An outcome pip in the corner says whether the event succeeded,
/// so severity never relies on colour alone.
struct ActivityThumbnail: View {
    let entry: LogEntry
    let store: AppStore?
    var size: CGFloat = DesignTokens.ActivityFeed.thumbnail

    private var outcome: LogRowIconography.Outcome? {
        LogRowIconography.outcome(for: entry)
    }

    var body: some View {
        let visual = LogRowIconography.visual(for: entry, store: store)
        avatar(for: visual)
            .frame(width: size, height: size)
            .overlay(alignment: .bottomTrailing) {
                if let outcome, showsPip(for: visual) {
                    pip(outcome)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func avatar(for visual: LogRowIconography.Visual) -> some View {
        switch visual {
        case .deviceThumbnail(let device):
            DeviceImageView(device: device, isAvailable: true, size: size, showsAvailabilityIndicator: false)
        case .groupThumbnail(_, let members):
            GroupIconView(memberDevices: Array(members.prefix(2)), size: size)
        case .symbol(let name, let tint):
            symbol(name: name, tint: tint)
        }
    }

    @ViewBuilder
    private func symbol(name: String, tint: Color) -> some View {
        let glyph = Image(systemName: name)
            .font(.system(size: size * DesignTokens.ActivityFeed.glyphRatio, weight: .semibold))
        switch LogRowIconography.emphasis(for: entry) {
        case .quiet:
            glyph
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(.fill.tertiary, in: Circle())
        case .standard:
            glyph
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(tint.opacity(DesignTokens.Opacity.softFill), in: Circle())
        case .loud:
            glyph
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(tint, in: Circle())
        }
    }

    /// A loud symbol already says "failed", and a general message's glyph
    /// is its severity symbol; a pip on top of either would repeat it.
    private func showsPip(for visual: LogRowIconography.Visual) -> Bool {
        if case .symbol = visual {
            return LogRowIconography.emphasis(for: entry) != .loud && entry.category != .general
        }
        return true
    }

    private func pip(_ outcome: LogRowIconography.Outcome) -> some View {
        let tokens = DesignTokens.ActivityFeed.self
        return Image(systemName: outcome.systemImage)
            .font(.system(size: tokens.pip * tokens.pipGlyphRatio, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: tokens.pip, height: tokens.pip)
            .background(outcome.tint, in: Circle())
            .padding(tokens.pipBorder)
            .background(Color(.secondarySystemGroupedBackground), in: Circle())
            .offset(x: tokens.pipOffset, y: tokens.pipOffset)
    }
}
