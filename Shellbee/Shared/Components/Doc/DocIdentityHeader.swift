import SwiftUI

/// Identity card at the top of a Documentation page: the device image,
/// z2m's description as the name, vendor and model in secondary text, and a
/// `StatStrip` of type, power, OTA and the number of exposes.
struct DocIdentityHeader: View {
    let device: Device
    let identity: DeviceDocIdentity
    /// Overrides the device's Zigbee type, e.g. "Light" for a Device Library
    /// entry, which has no network role.
    var typeLabel: String? = nil
    var exposeCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                DeviceImageView(
                    device: device,
                    isAvailable: true,
                    size: DesignTokens.Size.deviceHeroImage,
                    showsAvailabilityIndicator: false
                )
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(identity.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(identity.vendorAndModel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            StatStrip(items: stats)
        }
        .cardSurface()
    }

    private var stats: [StatStripItem] {
        var items: [StatStripItem] = []
        if let type = typeLabel ?? (device.type == .unknown ? nil : device.type.chipLabel) {
            items.append(StatStripItem(value: type, caption: "Type"))
        }
        if let power = device.shortPowerSource {
            items.append(StatStripItem(value: power, caption: "Power"))
        }
        items.append(StatStripItem(value: identity.supportsOTA ? "Supported" : "No", caption: "OTA"))
        if exposeCount > 0 {
            items.append(StatStripItem(value: "\(exposeCount)", caption: "Exposes"))
        }
        return items
    }
}

extension DeviceDocIdentity {
    /// z2m's description is what people recognise; the model number is the
    /// fallback for entries without one.
    var displayName: String { description.isEmpty ? model : description }

    var vendorAndModel: String {
        description.isEmpty ? vendor : "\(vendor) · \(model)"
    }
}

private extension Device {
    /// "Mains (single phase)" → "Mains", so the value fits a stat cell.
    var shortPowerSource: String? {
        guard let powerSource, !powerSource.isEmpty else { return nil }
        let short = powerSource.components(separatedBy: " (").first ?? powerSource
        return short == "DC Source" ? "DC" : short
    }
}
