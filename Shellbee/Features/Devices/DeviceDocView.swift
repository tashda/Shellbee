import SwiftUI
import OSLog

private let log = Logger(subsystem: "dev.echodb.shellbee", category: "DeviceDocView")

struct DeviceDocView: View {
    let bridgeID: UUID
    let device: Device
    @Environment(AppEnvironment.self) private var environment
    @State private var documentation: DeviceDocumentation?
    @State private var loadError: DeviceDocError?
    @State private var isLoading = false
    @State private var showPairingGuide = false

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    var body: some View {
        content
            .environment(\.docContextDevice, device)
            .environment(\.docContextBridgeID, bridgeID)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadDoc() }
            .sheet(isPresented: $showPairingGuide) {
                if let documentation {
                    PairingGuideSheet(
                        bridgeID: bridgeID,
                        device: device,
                        documentation: documentation
                    )
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let documentation, !documentation.parsed.isEmpty {
            DocumentationExperienceView(
                device: device,
                documentation: documentation,
                openPairing: documentation.normalized.pairing == nil ? nil : { showPairingGuide = true }
            )
        } else {
            placeholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shellbeeThemedCanvas(fallback: Color(.systemGroupedBackground))
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if isLoading {
            VStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                Text("Loading documentation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if let error = loadError {
            errorView(error)
        } else if documentation != nil {
            ContentUnavailableView(
                "No Documentation",
                systemImage: "doc.questionmark",
                description: Text("No documentation is available for \(device.definition?.model ?? "this device").")
            )
        }
    }

    @ViewBuilder
    private func errorView(_ error: DeviceDocError) -> some View {
        ContentUnavailableView(
            "Documentation Unavailable",
            systemImage: "wifi.exclamationmark",
            description: Text(error.localizedDescription)
        )
    }

    private func loadDoc() async {
        guard let model = device.definition?.model else {
            log.warning("loadDoc: no model — skipping")
            return
        }
        let version = scope.bridgeInfo?.version ?? "master"
        log.debug("loadDoc: model=\(model) version=\(version)")
        isLoading = true
        defer { isLoading = false }
        do {
            documentation = try await DeviceDocService.shared.doc(for: device, z2mVersion: version)
            log.debug("loadDoc: success, sections=\(documentation?.parsed.sections.count ?? 0)")
        } catch let err as DeviceDocError {
            log.error("loadDoc: DeviceDocError — \(err.localizedDescription)")
            loadError = err
        } catch {
            log.error("loadDoc: unexpected error — \(error)")
            loadError = .networkError(error)
        }
    }
}

#Preview {
    NavigationStack {
        DeviceDocView(bridgeID: UUID(), device: .preview)
            .environment(AppEnvironment())
    }
    .configuredTopScrollEdgeEffect()
}
