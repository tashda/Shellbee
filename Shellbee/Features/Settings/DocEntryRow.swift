import SwiftUI

/// A Device Library entry: z2m's description as the title, the model (and
/// the vendor when the list isn't already grouped by it) in secondary text.
struct DocEntryRow: View {
    let entry: DocBrowserEntry
    var showVendor: Bool = false
    /// How many of these are paired, shown as a trailing count.
    var ownedCount: Int? = nil

    @State private var bundledImage: UIImage?

    init(entry: DocBrowserEntry, showVendor: Bool = false, ownedCount: Int? = nil) {
        self.entry = entry
        self.showVendor = showVendor
        self.ownedCount = ownedCount
        _bundledImage = State(initialValue: entry.imageKey.flatMap(BundledImageStore.cachedImage(for:)))
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            deviceImage
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(entry.description.isEmpty ? entry.model : entry.description)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let ownedCount {
                Text("\(ownedCount)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .task(id: entry.docKey) {
            guard bundledImage == nil, let key = entry.imageKey else { return }
            bundledImage = await BundledImageStore.shared.image(for: key)
        }
    }

    private var subtitle: String {
        if entry.description.isEmpty { return entry.vendor }
        return showVendor ? "\(entry.vendor) · \(entry.model)" : entry.model
    }

    @ViewBuilder
    private var deviceImage: some View {
        let size = DesignTokens.Size.summaryRowSymbolFrame
        if let uiImage = bundledImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .transition(.opacity)
        } else {
            PersistentAsyncImage(url: entry.networkImageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } placeholder: {
                Image(systemName: entry.deviceType?.systemImage ?? "cpu")
                    .font(.system(size: size * DesignTokens.Typography.iconRatioHalf, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - DocBrowserEntry network image URL (fallback when bundle unavailable)

private extension DocBrowserEntry {
    var networkImageURL: URL? {
        let stem = imageKey ?? model
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return URL(string: "https://www.zigbee2mqtt.io/images/devices/\(stem).png")
    }
}
