import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DeviceListRow: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?
    var checkResult: AppStore.DeviceCheckResult? = nil
    var isDeleting: Bool = false
    var isIdentifying: Bool = false
    /// When `false` the row renders inline (no NavigationLink wrapper, no
    /// chevron, no tap highlight). Used in the pairing wizard where there
    /// is no device-detail navigation destination registered.
    var navigates: Bool = true
    /// Phase 2 multi-bridge: source-bridge tag for the colored dot. Nil in
    /// single-bridge mode.
    var bridgeID: UUID? = nil
    var bridgeName: String = ""
    let onRename: () -> Void
    let onRemove: () -> Void
    let onReconfigure: () -> Void
    let onInterview: () -> Void
    let onIdentify: () -> Void
    let onUpdate: (() -> Void)?
    let onCheckUpdate: () -> Void
    let onSchedule: (() -> Void)?
    let onUnschedule: (() -> Void)?

    private var isBatteryPowered: Bool {
        guard let raw = device.powerSource?.lowercased() else { return false }
        return raw.contains("battery")
    }

    private var supportsOTA: Bool {
        device.definition?.supportsOTA == true
    }

    private var rejectionMessage: (text: String, icon: String)? {
        if !supportsOTA {
            return ("OTA not supported", "xmark.circle")
        }
        if otaStatus?.phase == .checking {
            return ("Checking", "arrow.triangle.2.circlepath")
        }
        if otaStatus?.isActive == true {
            return ("Updating", "arrow.up.circle")
        }
        if checkResult == .noUpdate {
            return ("No update found", "checkmark.circle")
        }
        return nil
    }

    private func rejectSwipe() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    @ViewBuilder
    private var rowBody: some View {
        // Multi-bridge attribution lives entirely on the trailing chevron via
        // `.tint(BridgeColor.color(for:))` on the NavigationLink (see
        // `rowContent`). The earlier leading color-bar variant was tested but
        // read as decorative noise when most rows were from the same bridge —
        // the chevron tint wins when only the outlier rows stand out.
        DeviceRowView(
            device: device,
            state: state,
            isAvailable: isAvailable,
            otaStatus: otaStatus,
            checkResult: checkResult,
            isDeleting: isDeleting,
            bridgeID: bridgeID,
            bridgeName: bridgeName
        )
    }

    @ViewBuilder
    private var rowContent: some View {
        if navigates, let bridgeID {
            // Phase 1: push a `DeviceRoute` that carries the device's source
            // bridge id alongside the device. The destination resolves the
            // right `BridgeScope` from the route.
            //
            // Multi-bridge attribution is handled at the row-background
            // layer (`.listRowBackground` below) — `.tint()` on a
            // NavigationLink does NOT propagate to the system disclosure
            // chevron in iOS 17+, so we rely on a subtle leading-edge
            // gradient on the row instead.
            NavigationLink(value: DeviceRoute(bridgeID: bridgeID, device: device)) { rowBody }
        } else if navigates {
            // Defensive: a nav-capable row with no bridgeID has nothing to
            // route to. Render plain so taps don't no-op silently.
            rowBody
        } else {
            rowBody
        }
    }

    var body: some View {
        rowContent
        // Multi-bridge attribution: a thin colored bar on the cell's leading
        // edge, full row height. Visibility honors the Bridge Indicator
        // setting (Settings → Application → General → Appearance).
        .listRowBackground(BridgeRowLeadingBar(bridgeID: bridgeID))
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if otaStatus?.phase == .scheduled, let onUnschedule {
                Button(action: onUnschedule) {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .tint(.orange)
            } else if let rejection = rejectionMessage {
                Button(action: rejectSwipe) {
                    Label(rejection.text, systemImage: rejection.icon)
                }
                .tint(.gray)
            } else {
                Button(action: onCheckUpdate) {
                    Label("Check", systemImage: "arrow.triangle.2.circlepath")
                }
                .tint(.blue)
                if isBatteryPowered {
                    if let onSchedule {
                        Button(action: onSchedule) {
                            Label("Schedule", systemImage: "calendar.badge.clock")
                        }
                        .tint(.indigo)
                    }
                    if let onUpdate {
                        Button(action: onUpdate) {
                            Label("Update", systemImage: "arrow.up.circle")
                        }
                        .tint(.green)
                    }
                } else {
                    if let onUpdate {
                        Button(action: onUpdate) {
                            Label("Update", systemImage: "arrow.up.circle")
                        }
                        .tint(.green)
                    }
                    if let onSchedule {
                        Button(action: onSchedule) {
                            Label("Schedule", systemImage: "calendar.badge.clock")
                        }
                        .tint(.indigo)
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Intentionally NOT role: .destructive — that makes SwiftUI's List
            // animate the row out as if deleted, but our data source still
            // contains the device until z2m confirms. The UICollectionView
            // diff then asserts ("0 inserted, 1 deleted"). We mark the row
            // "Deleting" instead and remove it on bridge/response/device/remove.
            Button(action: { if !isDeleting { onRemove() } }) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.orange)
            Button(action: onReconfigure) {
                Label("Config", systemImage: "gearshape")
            }
            .tint(.gray)
            Button(action: onInterview) {
                Label("Interview", systemImage: "questionmark.circle")
            }
            .tint(.purple)
            if device.supportsIdentify {
                Button(action: onIdentify) {
                    Label(isIdentifying ? "Identifying" : "Identify",
                          systemImage: isIdentifying ? "wave.3.right" : "wave.3.right.circle")
                }
                .tint(.teal)
                .disabled(isIdentifying)
            }
        }
        .contextMenu {
            if device.supportsIdentify {
                Button(action: onIdentify) {
                    Label("Identify", systemImage: "wave.3.right.circle")
                }
                .disabled(isIdentifying)
            }
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            Button(action: onReconfigure) {
                Label("Reconfigure", systemImage: "gearshape.fill")
            }
            Button(action: onInterview) {
                Label("Interview", systemImage: "questionmark.circle")
            }
            if supportsOTA {
                Divider()
                Button(action: onCheckUpdate) {
                    Label("Check for Update", systemImage: "arrow.triangle.2.circlepath")
                }
                if otaStatus?.phase == .scheduled, let onUnschedule {
                    Button(action: onUnschedule) {
                        Label("Cancel Scheduled Update", systemImage: "xmark.circle")
                    }
                } else {
                    // Both actions exposed when an update is available.
                    // Battery devices get Schedule listed first as the
                    // recommended path (Z2M waits for the device to wake);
                    // mains devices get Update Now first.
                    if isBatteryPowered {
                        if let onSchedule {
                            Button(action: onSchedule) {
                                Label("Schedule Update", systemImage: "calendar.badge.clock")
                            }
                        }
                        if let onUpdate {
                            Button(action: onUpdate) {
                                Label("Update Now", systemImage: "arrow.up.circle")
                            }
                        }
                    } else {
                        if let onUpdate {
                            Button(action: onUpdate) {
                                Label("Update Now", systemImage: "arrow.up.circle")
                            }
                        }
                        if let onSchedule {
                            Button(action: onSchedule) {
                                Label("Schedule Update", systemImage: "calendar.badge.clock")
                            }
                        }
                    }
                }
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("Remove Device", systemImage: "trash")
            }
            .disabled(isDeleting)
        }
    }

}

#Preview {
    NavigationStack {
        List {
            DeviceListRow(
                device: .preview,
                state: [:],
                isAvailable: true,
                otaStatus: OTAUpdateStatus(deviceName: "Preview Device", phase: .requested, progress: nil, remaining: nil),
                onRename: {},
                onRemove: {},
                onReconfigure: {},
                onInterview: {},
                onIdentify: {},
                onUpdate: {},
                onCheckUpdate: {},
                onSchedule: {},
                onUnschedule: {}
            )
        }
    }
}
