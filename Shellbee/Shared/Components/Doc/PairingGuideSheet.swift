import SwiftUI

/// Presents a loaded pairing guide as a sheet with its own navigation, so
/// the other ways to pair and joined devices can push within it.
struct PairingGuideSheet: View {
    let bridgeID: UUID?
    let device: Device
    let documentation: DeviceDocumentation

    var body: some View {
        PairingGuideSheetChrome {
            PairingGuideExperienceView(
                device: device,
                identity: documentation.normalized.identity,
                pairing: documentation.normalized.pairing,
                sourcePath: documentation.sourcePath,
                bridgeID: bridgeID
            )
        }
        .environment(\.docContextDevice, device)
        .environment(\.docContextBridgeID, bridgeID)
    }
}

/// Navigation, title and close button shared by every pairing guide sheet.
struct PairingGuideSheetChrome<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .navigationTitle("How to pair")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
        }
        .configuredTopScrollEdgeEffect()
    }
}
