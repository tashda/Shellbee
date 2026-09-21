import SwiftUI

struct DocEntryRow: View {
    let entry: DocBrowserEntry
    var showVendor: Bool = false

    @State private var bundledImageData: Data?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            deviceImage
            VStack(alignment: .leading, spacing: 0) {
                if showVendor {
                    Text(entry.vendor.uppercased())
                        .font(.system(size: DesignTokens.Size.chipSymbol, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary.opacity(DesignTokens.Opacity.secondaryText))
                        .lineLimit(1)
                }
                Text(entry.model)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !entry.description.isEmpty {
                    Text(entry.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .task(id: entry.docKey) {
            bundledImageData = nil
            if let key = entry.imageKey {
                bundledImageData = await BundledImageStore.shared.imageData(for: key)
            }
        }
    }

    @ViewBuilder
    private var deviceImage: some View {
        let size = DesignTokens.Size.summaryRowSymbolFrame
        if let data = bundledImageData, let uiImage = UIImage(data: data) {
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
                    .foregroundStyle(Color.accentColor)
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
