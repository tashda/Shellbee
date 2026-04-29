import SwiftUI

struct LogRowView: View {
    @Environment(AppEnvironment.self) private var environment
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            leadingVisual

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Text(entry.summaryTitle)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer(minLength: DesignTokens.Spacing.sm)
                    absoluteTimestamp
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(entry.summarySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: DesignTokens.Spacing.xs)
                    relativeTimestamp
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.summaryRowVerticalPadding)
    }

    // MARK: - Leading visual

    private var leadingVisual: some View {
        let size = DesignTokens.Size.logRowDeviceImage
        let badgeSize = size * 0.47

        return ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(entry.level.color)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: entry.category.systemImage)
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }

            if let device = resolvedDevice {
                deviceThumbnail(device, size: badgeSize)
                    .offset(x: 3, y: 3)
            }
        }
    }

    private var iconForeground: Color {
        entry.level == .warning ? Color.black.opacity(DesignTokens.Opacity.secondaryDim) : Color.white
    }

    private func deviceThumbnail(_ device: Device, size: CGFloat) -> some View {
        DeviceImageView(device: device, isAvailable: true, size: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: max(1.5, size * 0.1)))
    }

    private var resolvedDevice: Device? {
        let name: String?
        if let ctx = entry.context, !ctx.devices.isEmpty {
            name = ctx.devices.first?.friendlyName
        } else if let n = entry.deviceName {
            name = n
        } else if case .mqttPublish(let d, _, _) = entry.parsedMessageKind {
            name = d
        } else {
            name = nil
        }
        return name.flatMap { environment.store.device(named: $0) }
    }

    // MARK: - Timestamps

    private var absoluteTimestamp: some View {
        Text(entry.timestamp, format: .dateTime.hour().minute().second())
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private var relativeTimestamp: some View {
        Text(entry.timestamp, style: .relative)
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

#Preview {
    List {
        ForEach(LogEntry.previewEntries) { entry in
            LogRowView(entry: entry)
        }
    }
    .listStyle(.plain)
    .environment(AppEnvironment())
}
