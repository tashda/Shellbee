import SwiftUI

struct LogRowView: View {
    @Environment(AppEnvironment.self) private var environment
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            leadingVisual

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Text(entry.summaryTitle)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Spacer(minLength: DesignTokens.Spacing.sm)
                    absoluteTimestamp
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: entry.category.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(entry.category.chipTint)
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

    @ViewBuilder
    private var leadingVisual: some View {
        let resolved = resolvedDevices
        let size = DesignTokens.Size.logRowDeviceImage
        ZStack(alignment: .bottomTrailing) {
            switch resolved.count {
            case 2:
                ZStack(alignment: .topLeading) {
                    deviceImage(resolved[0], size: size * 0.72)
                    deviceImage(resolved[1], size: size * 0.72)
                        .offset(x: size * 0.28, y: size * 0.28)
                }
                .frame(width: size, height: size, alignment: .topLeading)
            case 1:
                deviceImage(resolved[0], size: size)
                    .frame(width: size, height: size, alignment: .top)
            default:
                fallbackSymbol
            }
            levelBadge(size: size)
        }
    }

    private func deviceImage(_ device: Device, size: CGFloat) -> some View {
        DeviceImageView(
            device: device,
            isAvailable: environment.store.isAvailable(device.friendlyName),
            size: size
        )
    }

    private func levelBadge(size: CGFloat) -> some View {
        let badge = size * 0.44
        return ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: badge, height: badge)
            Image(systemName: entry.level.systemImage)
                .font(.system(size: badge * 0.60, weight: .semibold))
                .foregroundStyle(entry.level.color)
        }
        .offset(x: DesignTokens.Spacing.xs, y: DesignTokens.Spacing.xs)
    }

    // Resolve device names → Device objects, max 2
    private var resolvedDevices: [Device] {
        let names: [String]
        if let ctx = entry.context, !ctx.devices.isEmpty {
            names = ctx.devices.map(\.friendlyName)
        } else if let name = entry.deviceName {
            names = [name]
        } else if case .mqttPublish(let d, _, _) = entry.parsedMessageKind {
            names = [d]
        } else {
            return []
        }
        return names.prefix(2).compactMap { environment.store.device(named: $0) }
    }

    // MARK: - Supporting views

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

    private var fallbackSymbol: some View {
        let size = DesignTokens.Size.logRowDeviceImage
        return Image(systemName: fallbackSymbolName)
            .font(.system(size: size * 0.48, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: size, height: size, alignment: .top)
    }

    private var fallbackSymbolName: String {
        if let namespace = entry.namespace?.lowercased() {
            if namespace.contains("mqtt") { return "antenna.radiowaves.left.and.right" }
            if namespace.contains("bridge") { return "cpu" }
            if namespace.contains("controller") { return "dot.radiowaves.left.and.right" }
        }
        return entry.category.systemImage
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
