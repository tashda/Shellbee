import SwiftUI

/// Bottom sheet opened from the Home Bridge card. Shows one bridge's
/// connection details (URL, transport, status) alongside the metadata the
/// bridge reports about itself: Zigbee2MQTT version, coordinator, network,
/// and the latest health check. Reads the session live so values update while
/// the sheet is open.
struct BridgeInfoSheet: View {
    let bridgeID: UUID

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    private var session: BridgeSession? {
        environment.registry.session(for: bridgeID)
    }

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if let session {
                    content(for: session)
                } else {
                    ContentUnavailableView("Bridge Unavailable", systemImage: "antenna.radiowaves.left.and.right.slash")
                }
            }
            .navigationTitle(session?.displayName ?? "Bridge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .configuredTopScrollEdgeEffect()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func content(for session: BridgeSession) -> some View {
        let config = session.config
        let info = session.store.bridgeInfo
        let health = session.store.bridgeHealth

        return Form {
            Section("Connection") {
                LabeledContent("Status", value: statusText(for: session))
                CopyableRow(label: "URL", value: config.displayURL)
                if let webSocket = webSocketText(for: config) {
                    CopyableRow(label: "WebSocket", value: webSocket)
                        .monospaced()
                }
                LabeledContent("TLS", value: config.useTLS ? "On" : "Off")
                if config.useTLS && config.allowInvalidCertificates {
                    LabeledContent("Certificate Validation", value: "Off")
                }
                LabeledContent("Auth Token", value: config.authToken?.isEmpty == false ? "Configured" : "None")
            }

            if let info {
                Section("Zigbee2MQTT") {
                    CopyableRow(label: "Version", value: info.version)
                    if let commit = info.commit, !commit.isEmpty {
                        CopyableRow(label: "Commit", value: String(commit.prefix(7)))
                            .monospaced()
                    }
                    LabeledContent("Bridge", value: session.store.bridgeOnline ? "Online" : "Offline")
                    LabeledContent("Log Level", value: info.logLevel.capitalized)
                    if info.restartRequired {
                        LabeledContent("Restart Required", value: "Yes")
                    }
                }

                Section("Coordinator") {
                    if let type = info.coordinator.type {
                        CopyableRow(label: "Type", value: type)
                    }
                    if let ieee = info.coordinator.ieeeAddress {
                        CopyableRow(label: "IEEE Address", value: ieee)
                            .monospaced()
                    }
                    if let revision = info.coordinator.meta?["revision"]?.stringified {
                        CopyableRow(label: "Revision", value: revision)
                    }
                }

                if let network = info.network {
                    Section("Network") {
                        CopyableRow(label: "Channel", value: "\(network.channel)")
                        CopyableRow(label: "PAN ID", value: String(format: "0x%04X", network.panID))
                            .monospaced()
                        if let extended = network.extendedPanID?.stringified {
                            CopyableRow(label: "Extended PAN ID", value: extended)
                                .monospaced()
                        }
                    }
                }
            }

            if let health {
                healthSection(health)
            }
        }
    }

    @ViewBuilder
    private func healthSection(_ health: BridgeHealth) -> some View {
        Section("Health") {
            if let uptime = health.process?.uptimeFormatted {
                LabeledContent("Uptime", value: uptime)
            }
            if let memory = memoryText(mb: health.process?.rssMB, percent: health.process?.ramPercentFormatted) {
                LabeledContent("Zigbee2MQTT Memory", value: memory)
            }
            if let memory = memoryText(mb: health.os?.ramMB, percent: health.os?.ramPercentFormatted) {
                LabeledContent("System Memory", value: memory)
            }
            if let load = health.os?.loadAverage, !load.isEmpty {
                LabeledContent("Load Average", value: load.map { String(format: "%.2f", $0) }.joined(separator: " · "))
            }
            if let response = health.responseTime {
                LabeledContent("Response Time", value: String(format: "%.0f ms", response))
            }
        }
        if let mqtt = health.mqtt {
            Section("MQTT") {
                if let connected = mqtt.connected {
                    LabeledContent("Status", value: connected ? "Connected" : "Disconnected")
                }
                if let published = mqtt.published {
                    LabeledContent("Published", value: published.formatted())
                }
                if let received = mqtt.received {
                    LabeledContent("Received", value: received.formatted())
                }
                if let queued = mqtt.queued {
                    LabeledContent("Queued", value: queued.formatted())
                }
            }
        }
    }

    private func statusText(for session: BridgeSession) -> String {
        switch session.connectionState {
        case .idle: "Not Connected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .reconnecting(let attempt): "Reconnecting (\(attempt))"
        case .failed: "Failed"
        case .lost: "Connection Lost"
        }
    }

    /// WebSocket endpoint with the auth token query stripped — the token must
    /// never be displayed or copied from here.
    private func webSocketText(for config: ConnectionConfig) -> String? {
        guard let url = config.webSocketURL,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        components.queryItems = nil
        return components.string
    }

    private func memoryText(mb: String?, percent: String?) -> String? {
        switch (mb, percent) {
        case let (mb?, percent?): "\(mb) (\(percent))"
        case let (mb?, nil): mb
        case let (nil, percent?): percent
        case (nil, nil): nil
        }
    }
}
