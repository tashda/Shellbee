import SwiftUI
import OSLog

private let log = Logger(subsystem: "dev.echodb.shellbee", category: "DocBrowserDetailView")

struct DocBrowserDetailView: View {
    let entry: DocBrowserEntry
    @Environment(AppEnvironment.self) private var environment
    @State private var documentation: DeviceDocumentation?
    @State private var loadError: DeviceDocError?
    @State private var showPairingGuide = false

    var body: some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadDoc() }
            .sheet(isPresented: $showPairingGuide) {
                if let documentation {
                    PairingGuideSheet(
                        bridgeID: environment.registry.primaryBridgeID,
                        device: previewDevice,
                        documentation: documentation
                    )
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let documentation {
            DocumentationExperienceView(
                device: previewDevice,
                documentation: documentation,
                typeLabel: entry.deviceType?.singularTitle,
                openPairing: documentation.normalized.pairing == nil ? nil : { showPairingGuide = true }
            )
        } else {
            SwiftUI.Group {
                if let error = loadError {
                    ContentUnavailableView(
                        "Documentation Unavailable",
                        systemImage: "doc.questionmark",
                        description: Text(error.localizedDescription)
                    )
                } else {
                    VStack(spacing: DesignTokens.Spacing.md) {
                        ProgressView()
                        Text("Loading documentation")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shellbeeThemedCanvas(fallback: Color(.systemGroupedBackground))
        }
    }

    // Minimal device for display; exposes are empty so Capabilities section is hidden.
    private var previewDevice: Device {
        Device(
            ieeeAddress: "doc-browser-\(entry.docKey)",
            type: .unknown,
            networkAddress: 0,
            supported: true,
            friendlyName: entry.model,
            disabled: false,
            description: entry.description,
            definition: DeviceDefinition(
                model: entry.model,
                vendor: entry.vendor,
                description: entry.description,
                supportsOTA: false,
                exposes: [],
                options: nil,
                icon: nil
            ),
            powerSource: entry.isBatteryPowered ? "Battery" : nil,
            modelId: entry.model,
            manufacturer: entry.vendor,
            interviewCompleted: true,
            interviewing: false,
            softwareBuildId: nil,
            dateCode: nil,
            endpoints: nil,
            options: nil
        )
    }

    private func loadDoc() async {
        // Phase 2 multi-bridge: docs are not bridge-scoped, but the version
        // we use for the URL has to come from somewhere — pick the user's
        // selected bridge's version, falling back to master.
        let version = environment.selectedScope?.store.bridgeInfo?.version ?? "master"
        do {
            documentation = try await DeviceDocService.shared.doc(for: entry, z2mVersion: version)
        } catch let err as DeviceDocError {
            log.error("DocBrowserDetailView: \(err.localizedDescription)")
            loadError = err
        } catch {
            loadError = .networkError(error)
        }
    }
}
