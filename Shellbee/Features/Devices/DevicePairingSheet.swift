import SwiftUI

struct DevicePairingSheet: View {
    let bridgeID: UUID
    let device: Device
    @Environment(AppEnvironment.self) private var environment
    @State private var documentation: DeviceDocumentation?
    @State private var notFound = false

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    var body: some View {
        PairingGuideSheetChrome {
            content
        }
        .environment(\.docContextDevice, device)
        .environment(\.docContextBridgeID, bridgeID)
        .task { await loadPairing() }
    }

    @ViewBuilder
    private var content: some View {
        if let documentation {
            PairingGuideExperienceView(
                device: device,
                identity: documentation.normalized.identity,
                pairing: documentation.normalized.pairing,
                sourcePath: documentation.sourcePath,
                bridgeID: bridgeID
            )
        } else if notFound {
            ContentUnavailableView(
                "No Pairing Instructions",
                systemImage: "doc.questionmark",
                description: Text("Pairing instructions aren't documented for \(device.definition?.model ?? "this device").")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shellbeeThemedCanvas()
        } else {
            VStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                Text("Loading pairing instructions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shellbeeThemedCanvas()
        }
    }

    private func loadPairing() async {
        guard device.definition?.model != nil else { notFound = true; return }
        let version = scope.bridgeInfo?.version ?? "master"
        do {
            documentation = try await DeviceDocService.shared.doc(for: device, z2mVersion: version)
            if documentation?.normalized.pairing == nil { notFound = true }
        } catch {
            notFound = true
        }
    }
}

#Preview {
    DevicePairingSheet(bridgeID: UUID(), device: .preview)
        .environment(AppEnvironment())
}
