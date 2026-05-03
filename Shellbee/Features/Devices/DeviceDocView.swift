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
        ScrollView {
            content
        }
        .environment(\.docContextDevice, device)
        .environment(\.docContextBridgeID, bridgeID)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Documentation")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if documentation?.normalized.pairing != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPairingGuide = true
                    } label: {
                        Label("Pairing Guide", systemImage: "personalhotspot")
                    }
                }
            }
        }
        .task { await loadDoc() }
        .sheet(isPresented: $showPairingGuide) {
            if let documentation {
                NavigationStack {
                    PairingGuideExperienceView(
                        device: device,
                        identity: documentation.normalized.identity,
                        pairing: documentation.normalized.pairing,
                        sourcePath: documentation.sourcePath
                    )
                    .navigationTitle("How to Pair")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Done") { showPairingGuide = false }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            HStack {
                Spacer()
                VStack(spacing: DesignTokens.Spacing.md) {
                    ProgressView()
                    Text("Loading documentation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.top, DesignTokens.Spacing.xxl)
        } else if let error = loadError {
            errorView(error)
                .padding(.horizontal, DesignTokens.Spacing.lg)
        } else if let documentation {
            if documentation.parsed.isEmpty {
                ContentUnavailableView(
                    "No Documentation",
                    systemImage: "doc.questionmark",
                    description: Text("No documentation is available for \(device.definition?.model ?? "this device").")
                )
                .padding(.top, DesignTokens.Spacing.xxl)
            } else {
                DocumentationExperienceView(
                    device: device,
                    documentation: documentation,
                    openPairing: documentation.normalized.pairing == nil ? nil : { showPairingGuide = true }
                )
            }
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
}
