import SwiftUI

/// Shared hero card used at the top of device documentation and pairing guide screens.
/// Callers supply identity/text and an optional trailing `extras` slot for chips,
/// expose summaries, or anything else that varies by usage.
struct DocHeroCard<Extras: View>: View {
    let device: Device
    let eyebrow: String?
    let title: String
    let description: [InlineSpan]
    let sourcePath: String?
    let gradient: [Color]
    @ViewBuilder let extras: () -> Extras

    init(
        device: Device,
        eyebrow: String?,
        title: String,
        description: [InlineSpan],
        sourcePath: String?,
        gradient: [Color] = DocHeroCard.defaultGradient,
        @ViewBuilder extras: @escaping () -> Extras = { EmptyView() }
    ) {
        self.device = device
        self.eyebrow = eyebrow
        self.title = title
        self.description = description
        self.sourcePath = sourcePath
        self.gradient = gradient
        self.extras = extras
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                DeviceImageView(device: device, isAvailable: true, size: DesignTokens.Size.deviceActionSheetImage * 1.4)
                    .frame(width: DesignTokens.Size.deviceActionSheetImage * 1.5, height: DesignTokens.Size.deviceActionSheetImage * 1.5)
                    .shadow(color: Color.black.opacity(DesignTokens.Opacity.hairline), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    if let eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(title)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    if !description.isEmpty {
                        DocInlineTextView(spans: description, sourcePath: sourcePath)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            extras()
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.xl, style: .continuous)
        )
    }

    static var defaultGradient: [Color] {
        [
            Color.accentColor.opacity(DesignTokens.Opacity.mildOpaque),
            Color.blue.opacity(DesignTokens.Opacity.mediumAccentFill),
            Color.blue.opacity(DesignTokens.Opacity.offStateTint)
        ]
    }

    static var pairingGradient: [Color] {
        [
            Color.blue.opacity(DesignTokens.Opacity.mildOpaque),
            Color.cyan.opacity(DesignTokens.Opacity.mediumAccentFill),
            Color.cyan.opacity(DesignTokens.Opacity.offStateTint)
        ]
    }
}

extension DocHeroCard where Extras == EmptyView {
    init(
        device: Device,
        eyebrow: String?,
        title: String,
        description: [InlineSpan],
        sourcePath: String?,
        gradient: [Color] = DocHeroCard.defaultGradient
    ) {
        self.device = device
        self.eyebrow = eyebrow
        self.title = title
        self.description = description
        self.sourcePath = sourcePath
        self.gradient = gradient
        self.extras = { EmptyView() }
    }
}

/// A small chip used inside the hero's extras slot (OTA, power source, etc.).
struct DocHeroChip: View {
    let label: String
    let tint: Color

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Size.compactChipVerticalPadding)
            .background(tint.opacity(DesignTokens.Opacity.chipFill), in: Capsule())
            .foregroundStyle(tint)
    }
}
