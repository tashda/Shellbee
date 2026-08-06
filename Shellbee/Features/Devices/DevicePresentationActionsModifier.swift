import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DevicePresentationActionsModifier: ViewModifier {
    let bound: BridgeBoundDevice
    let actions: DevicePresentationActions

    func body(content: Content) -> some View {
        let payload = DeviceTransferPayload(
            device: bound.device,
            bridgeID: bound.bridgeID,
            bridgeName: bound.bridgeName
        )
        content
            .draggable(payload) {
                DeviceTransferPreview(
                    device: bound.device,
                    isAvailable: actions.isAvailable,
                    otaStatus: actions.otaStatus
                )
            }
            .contextMenu {
                Button(action: copyInformation) {
                    Label("Copy Device Information", systemImage: "doc.on.doc")
                }
                Button(action: addToFavorites) {
                    Label("Add to Favorites", systemImage: "star")
                }
                if bound.device.supportsIdentify {
                    Button(action: actions.identify) {
                        Label(actions.isIdentifying ? "Identifying" : "Identify", systemImage: "wave.3.right.circle")
                    }
                    .disabled(actions.isIdentifying)
                }
                Button(action: actions.checkUpdate) {
                    Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
                }
                if actions.otaStatus?.phase == .scheduled {
                    Button(action: actions.unschedule) {
                        Label("Cancel Scheduled Update", systemImage: "xmark.circle")
                    }
                }
                if let update = actions.update {
                    Button(action: update) { Label("Update", systemImage: "arrow.up.circle") }
                }
                if let schedule = actions.schedule {
                    Button(action: schedule) { Label("Schedule", systemImage: "calendar.badge.clock") }
                }
                Divider()
                Button(action: actions.rename) { Label("Rename", systemImage: "pencil") }
                Button(action: actions.reconfigure) { Label("Configure", systemImage: "gearshape") }
                Button(action: actions.interview) { Label("Interview", systemImage: "questionmark.circle") }
                Button(role: .destructive, action: actions.remove) {
                    Label("Remove Device", systemImage: "trash")
                }
            }
            .accessibilityAction(named: "Copy Device Information", copyInformation)
            .accessibilityAction(named: "Add to Favorites", addToFavorites)
            .accessibilityAction(named: "Rename", actions.rename)
            .accessibilityAction(named: "Configure", actions.reconfigure)
            .accessibilityAction(named: "Interview", actions.interview)
            .accessibilityAction(named: "Check for Updates", actions.checkUpdate)
            .accessibilityAction(named: "Remove Device", actions.remove)
            .iPadPointerEffect(.highlight)
    }

    private func copyInformation() {
        #if canImport(UIKit)
        UIPasteboard.general.string = transferPayload.plainText
        #endif
    }

    private func addToFavorites() {
        if DeviceFavoritesStore().add(transferPayload) {
            Haptics.impact(.light)
        }
    }

    private var transferPayload: DeviceTransferPayload {
        DeviceTransferPayload(
            device: bound.device,
            bridgeID: bound.bridgeID,
            bridgeName: bound.bridgeName
        )
    }
}
