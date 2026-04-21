import SwiftUI

struct DeviceMetricItem: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: DesignTokens.Size.deviceCardMetricIconHeight)

            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: DesignTokens.Size.deviceCardMetricValueHeight)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HStack {
        DeviceMetricItem(label: "Link Quality", value: "120", systemImage: "wifi")
        DeviceMetricItem(label: "Battery", value: "85%", systemImage: "battery.100")
        DeviceMetricItem(label: "Firmware", value: "1.2.3", systemImage: "cpu")
    }
    .padding()
}
