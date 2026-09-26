import SwiftUI

/// Every Activity icon at every size it is drawn, rendered by the real
/// iconography code, so glyph and tier changes can be checked side by side
/// in light, dark and on glass.
struct ActivityIconGalleryView: View {
    @State private var colorScheme: ColorScheme = .light

    var body: some View {
        List {
            Section {
                Picker("Appearance", selection: $colorScheme) {
                    Text("Light").tag(ColorScheme.light)
                    Text("Dark").tag(ColorScheme.dark)
                }
                .pickerStyle(.segmented)
            }

            Section("Bridge Events") {
                ForEach(ActivityIconGallerySample.bridgeEvents) { sample in
                    row(sample)
                }
            }

            Section {
                ForEach(ActivityIconGallerySample.tiers) { sample in
                    row(sample)
                }
            } header: {
                Text("Emphasis and Outcomes")
            } footer: {
                Text("Quiet for noise, tinted for ordinary events, solid for failures. Pips mark success, warning and failure so colour is never the only signal.")
            }

            Section("Tab Bar Accessory") {
                accessoryPreview
            }
        }
        .environment(\.colorScheme, colorScheme)
        .navigationTitle("Activity Icons")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ sample: ActivityIconGallerySample) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.lg) {
                ForEach(DesignTokens.ActivityFeed.gallerySizes, id: \.self) { size in
                    ActivityThumbnail(entry: sample.entry, store: nil, size: size, pipBorder: Color(.secondarySystemGroupedBackground))
                }
            }
            Text(sample.name)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    private var accessoryPreview: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(ActivityIconGallerySample.accessory) { sample in
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ActivityThumbnail(
                        entry: sample.entry,
                        store: nil,
                        size: DesignTokens.ActivityFeed.accessoryArtwork,
                        pipBorder: .clear
                    )
                    Text(sample.name)
                        .font(.footnote.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
                .glassEffectIfAvailable(in: Capsule())
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .listRowBackground(
            LinearGradient(colors: [.blue, .purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

/// Synthetic events that exercise each branch of `LogRowIconography`.
struct ActivityIconGallerySample: Identifiable {
    let name: String
    let entry: LogEntry

    var id: String { name }

    static let bridgeEvents: [Self] = [
        ("Health Check", "health_check"), ("Info Refreshed", "info"), ("Options", "options"),
        ("Backup", "backup"), ("Restart", "restart"), ("Network Map", "networkmap"),
        ("Rename", "device/rename"), ("Remove", "device/remove"), ("Configure", "device/configure"),
        ("Bind", "device/bind"), ("OTA Check", "device/ota_update/check"),
        ("OTA Update", "device/ota_update/update"), ("Group Change", "group/members/add"),
        ("Touchlink", "touchlink/scan"), ("Unknown Request", "something_new")
    ].map { name, topic in
        Self(name: name, entry: bridgeResponse(topic, ok: true))
    }

    static let tiers: [Self] = [
        Self(name: "Quiet · Debug", entry: event(.debug, .general, "Received Zigbee message")),
        Self(name: "Standard · Info", entry: event(.info, .general, "Bridge message")),
        Self(name: "Standard · Warning", entry: event(.warning, .general, "Failed to ping device")),
        Self(name: "Standard · Joined", entry: event(.info, .deviceJoined, "Device joined")),
        Self(name: "Standard · Left", entry: event(.info, .deviceLeave, "Device left")),
        Self(name: "Standard · Pairing", entry: event(.info, .permitJoin, "Pairing opened")),
        Self(name: "Pip · Interview Successful", entry: event(.info, .interview, "Interview successful")),
        Self(name: "Loud · Request Failed", entry: bridgeResponse("device/bind", ok: false)),
        Self(name: "Loud · Error", entry: event(.error, .general, "Publish failed"))
    ]

    static let accessory: [Self] = [
        Self(name: "Bridge Health Check", entry: bridgeResponse("health_check", ok: true)),
        Self(name: "Failed to Bind", entry: bridgeResponse("device/bind", ok: false)),
        Self(name: "Pairing Opened", entry: event(.info, .permitJoin, "Pairing opened"))
    ]

    private static func bridgeResponse(_ topic: String, ok: Bool) -> LogEntry {
        let payload = ok ? #"{"status":"ok","data":{"healthy":true}}"# : #"{"status":"error","error":"Timeout"}"#
        return LogEntry(
            id: UUID(), timestamp: .now, level: .info, category: .bridgeActivity, namespace: "z2m:mqtt",
            message: "MQTT publish: topic 'zigbee2mqtt/bridge/response/\(topic)', payload '\(payload)'",
            deviceName: nil
        )
    }

    private static func event(_ level: LogLevel, _ category: LogCategory, _ message: String) -> LogEntry {
        LogEntry(
            id: UUID(), timestamp: .now, level: level, category: category,
            namespace: nil, message: message, deviceName: nil
        )
    }
}
