import SwiftUI

/// A device in a Home list (weakest links, batteries): its image, name and
/// description, and one reading on the trailing edge in its status colour.
struct HomeDeviceReadingRow: View {
    let reading: HomeDeviceReading
    let value: String
    var valueStyle: AnyShapeStyle = AnyShapeStyle(.secondary)
    var detail: String? = nil

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DeviceImageView(
                device: reading.device,
                isAvailable: true,
                size: DesignTokens.Size.logRowDeviceImage,
                showsAvailabilityIndicator: false
            )
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(reading.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(detail ?? reading.device.cardSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DesignTokens.Spacing.sm)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueStyle)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
