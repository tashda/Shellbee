import SwiftUI

/// Beautiful detail rendering for `bridge/health` payloads. The default
/// `BeautifulPayloadView` flattens the `devices` map into one "N properties"
/// row per device — useless for the user, who can't tell which IEEE is
/// which. This view does the IEEE → friendly-device lookup and renders
/// each device as its own grouped section: thumbnail + name + per-device
/// metrics, the same shape Settings uses for related controls.
///
/// Dispatched from `LogDetailView` when the entry is an MQTT publish on
/// the `bridge/health` topic.
struct LogHealthDetailSections: View {
    let payload: [String: JSONValue]
    let store: AppStore

    var body: some View {
        // Top-level health metrics (everything except the devices map),
        // plus a per-device section for each entry in `devices`.
        if let summary = healthSummary {
            Section("Health") {
                ForEach(summary, id: \.label) { row in
                    healthRow(label: row.label, value: row.value, valueColor: row.valueColor)
                }
            }
        }

        ForEach(deviceEntries, id: \.id) { entry in
            DeviceHealthSection(
                deviceMatch: entry.match,
                ieee: entry.ieee,
                metrics: entry.metrics
            )
        }
    }

    // MARK: - Health summary

    private struct HealthRow {
        let label: String
        let value: String
        let valueColor: Color
    }

    private var healthSummary: [HealthRow]? {
        var rows: [HealthRow] = []
        if let healthy = payload["healthy"]?.boolValue {
            rows.append(HealthRow(
                label: "Status",
                value: healthy ? "Healthy" : "Unhealthy",
                valueColor: healthy ? .green : .red
            ))
        }
        if let response = payload["response_time"]?.numberValue {
            rows.append(HealthRow(
                label: "Response time",
                value: formatResponseTime(response),
                valueColor: .primary
            ))
        }
        if let mqtt = payload["mqtt"]?.object {
            if let connected = mqtt["connected"]?.boolValue {
                rows.append(HealthRow(
                    label: "MQTT",
                    value: connected ? "Connected" : "Disconnected",
                    valueColor: connected ? .green : .red
                ))
            }
            if let queued = mqtt["queued"]?.numberValue {
                rows.append(HealthRow(
                    label: "MQTT queued",
                    value: "\(Int(queued))",
                    valueColor: queued > 0 ? .orange : .primary
                ))
            }
        }
        if let process = payload["process"]?.object {
            if let uptime = process["uptime_sec"]?.numberValue {
                rows.append(HealthRow(
                    label: "Uptime",
                    value: formatUptime(uptime),
                    valueColor: .primary
                ))
            }
            if let mem = process["memory_used_mb"]?.numberValue {
                rows.append(HealthRow(
                    label: "Memory",
                    value: String(format: "%.1f MB", mem),
                    valueColor: .primary
                ))
            }
        }
        return rows.isEmpty ? nil : rows
    }

    @ViewBuilder
    private func healthRow(label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - Per-device entries

    private struct DeviceEntry {
        let id: String      // IEEE
        let ieee: String
        let match: Device?
        let metrics: [(label: String, value: String, valueColor: Color)]
    }

    private var deviceEntries: [DeviceEntry] {
        guard case .object(let devices) = payload["devices"] ?? .null else { return [] }
        return devices.keys.sorted().compactMap { key -> DeviceEntry? in
            guard case .object(let metrics) = devices[key] ?? .null else { return nil }
            // Match IEEE case-insensitively — Z2M uses lowercase
            // (`0x000d6f...`) but the JSON key may have been re-cased
            // upstream, and `Device.ieeeAddress` always uses Z2M's form.
            let match = store.devices.first {
                $0.ieeeAddress.lowercased() == key.lowercased()
            }
            return DeviceEntry(
                id: key,
                ieee: key,
                match: match,
                metrics: Self.metricsRows(from: metrics)
            )
        }
    }

    /// Format the raw per-device metric map into render-ready rows. Known
    /// keys (leave_count, messages, messages_per_sec, network_address)
    /// get user-friendly labels and units; anything else falls through
    /// to a humanised key + raw value.
    private static func metricsRows(
        from raw: [String: JSONValue]
    ) -> [(label: String, value: String, valueColor: Color)] {
        let preferredOrder = ["messages", "messages_per_sec", "leave_count", "network_address"]
        let labels: [String: String] = [
            "messages": "Messages",
            "messages_per_sec": "Messages / sec",
            "leave_count": "Leave count",
            "network_address": "Network address"
        ]
        return raw
            .filter { if case .null = $0.value { return false }; return true }
            .sorted { lhs, rhs in
                let li = preferredOrder.firstIndex(of: lhs.key) ?? Int.max
                let ri = preferredOrder.firstIndex(of: rhs.key) ?? Int.max
                return li != ri ? li < ri : lhs.key < rhs.key
            }
            .map { key, value in
                let label = labels[key] ?? humanize(key)
                let formatted = formatMetric(key: key, value: value)
                let color: Color = (key == "leave_count" && (value.numberValue ?? 0) > 0) ? .orange : .primary
                return (label, formatted, color)
            }
    }

    private static func formatMetric(key: String, value: JSONValue) -> String {
        switch key {
        case "network_address":
            if let n = value.numberValue { return String(format: "0x%04X", Int(n)) }
            return value.stringified
        case "messages_per_sec":
            if let n = value.numberValue {
                return n.formatted(.number.precision(.fractionLength(0...2)))
            }
            return value.stringified
        default:
            switch value {
            case .int(let i): return "\(i)"
            case .double(let d):
                return d.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(d))"
                    : d.formatted(.number.precision(.fractionLength(0...2)))
            case .string(let s): return s
            case .bool(let b): return b ? "Yes" : "No"
            default: return value.stringified
            }
        }
    }

    // MARK: - Formatting helpers

    /// Z2M's `response_time` is a Unix-millis timestamp (when the snapshot
    /// was taken), not a duration. Render it as a relative timestamp so
    /// the user sees "just now" / "5 sec ago" instead of a giant integer.
    private func formatResponseTime(_ raw: Double) -> String {
        let date = Date(timeIntervalSince1970: raw / 1000)
        // If it's clearly nonsense (more than a year off), fall back to
        // the raw value — better than lying about freshness.
        if abs(date.timeIntervalSinceNow) > 60 * 60 * 24 * 365 {
            return "\(Int(raw)) ms"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func formatUptime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func humanize(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Per-device section

private struct DeviceHealthSection: View {
    let deviceMatch: Device?
    let ieee: String
    let metrics: [(label: String, value: String, valueColor: Color)]

    var body: some View {
        Section {
            // Inline header row: thumbnail + friendly name (or IEEE
            // fallback) + a small caption with the IEEE so the user can
            // verify identity. Same scale as DeviceCard.compact's leading
            // visual so health sections line up with other surfaces.
            HStack(spacing: DesignTokens.Spacing.md) {
                if let device = deviceMatch {
                    DeviceImageView(device: device, isAvailable: true, size: 36)
                        .frame(width: 36, height: 36)
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "questionmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(deviceMatch?.friendlyName ?? "Unknown device")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(ieee)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

            // Metric rows under the device header. Same `key: value`
            // shape as the diff rows in state-change details so the
            // visual language stays consistent.
            ForEach(metrics, id: \.label) { metric in
                HStack {
                    Text(metric.label)
                        .font(.subheadline)
                    Spacer()
                    Text(metric.value)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(metric.valueColor)
                }
            }
        }
    }
}
