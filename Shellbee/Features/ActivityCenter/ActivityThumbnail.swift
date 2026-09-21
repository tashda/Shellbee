import SwiftUI

/// Leading visual for an Activity card. Devices and groups show their real
/// product image; other events show a bare symbol, coloured by how much
/// it matters. Device images carry an outcome pip in the corner, so
/// severity never relies on colour alone.
struct ActivityThumbnail: View {
    let entry: LogEntry
    let store: AppStore?
    var size: CGFloat = DesignTokens.ActivityFeed.thumbnail
    /// Ring around the pip that separates it from the artwork; matches
    /// whatever the thumbnail sits on.
    var pipBorder: Color = Color(.secondarySystemGroupedBackground)
    /// Show the device image even for signal and battery reports, for
    /// places where the value is shown separately.
    var prefersSubjectImage = false

    var body: some View {
        let visual = resolvedVisual
        avatar(for: visual)
            .frame(width: size, height: size)
            .overlay(alignment: .bottomTrailing) {
                if let outcome = LogRowIconography.outcome(for: entry), showsPip(for: visual) {
                    pip(outcome)
                }
            }
            .accessibilityHidden(true)
    }

    private var resolvedVisual: LogRowIconography.Visual {
        if prefersSubjectImage, let subject = LogRowIconography.subjectVisual(for: entry, store: store) {
            return subject
        }
        return LogRowIconography.visual(for: entry, store: store)
    }

    @ViewBuilder
    private func avatar(for visual: LogRowIconography.Visual) -> some View {
        switch visual {
        case .deviceThumbnail(let device):
            DeviceImageView(device: device, isAvailable: true, size: size, showsAvailabilityIndicator: false)
        case .groupThumbnail(_, let members):
            GroupIconView(memberDevices: Array(members.prefix(2)), size: size)
        case .symbol(let name, let tint):
            if LogRowIconography.isLinkQualityOnly(entry) {
                signal
            } else {
                symbol(name: name, tint: tint)
            }
        }
    }

    /// Signal reports fill the Wi-Fi bars to the new link quality.
    private var signal: some View {
        let lqi = entry.context?.stateChanges.first { $0.property == "linkquality" }?.to
        return ActivityPropertyGlyph(property: "linkquality", value: lqi)
            .font(.system(size: size * DesignTokens.ActivityFeed.bareGlyphRatio, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func symbol(name: String, tint: Color) -> some View {
        let glyph = Image(systemName: name)
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: size * DesignTokens.ActivityFeed.bareGlyphRatio, weight: .semibold))
        switch LogRowIconography.emphasis(for: entry) {
        case .quiet:
            glyph.foregroundStyle(.secondary)
        case .standard:
            glyph.foregroundStyle(tint)
        case .loud:
            glyph.foregroundStyle(.red)
        }
    }

    /// Pips mark outcomes on device images. A bare symbol is already
    /// coloured by its outcome, and below a minimum size a pip would cover
    /// most of the artwork.
    private func showsPip(for visual: LogRowIconography.Visual) -> Bool {
        guard size >= DesignTokens.ActivityFeed.pipMinimumThumbnail else { return false }
        if case .symbol = visual { return false }
        return true
    }

    private func pip(_ outcome: LogRowIconography.Outcome) -> some View {
        let tokens = DesignTokens.ActivityFeed.self
        let pipSize = size * tokens.pipRatio
        let offset = size * tokens.pipOffsetRatio
        return Image(systemName: outcome.systemImage)
            .font(.system(size: pipSize * tokens.pipGlyphRatio, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: pipSize, height: pipSize)
            .background(outcome.tint, in: Circle())
            .padding(tokens.pipBorder)
            .background(pipBorder, in: Circle())
            .offset(x: offset, y: offset)
    }
}
