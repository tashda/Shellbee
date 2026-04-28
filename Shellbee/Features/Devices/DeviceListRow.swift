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
    let onRename: () -> Void
    let onRemove: () -> Void
    let onReconfigure: () -> Void
    let onInterview: () -> Void
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
            return ("Checking", "arrow.trianglehead.2.clockwise")
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

    var body: some View {
        NavigationLink(value: device) {
            DeviceRowView(
                device: device,
                state: state,
                isAvailable: isAvailable,
                otaStatus: otaStatus,
                checkResult: checkResult,
                isDeleting: isDeleting
            )
        }
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
                    Label("Check", systemImage: "arrow.trianglehead.2.clockwise")
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
        }
        .contextMenu {
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
                    Label("Check for Update", systemImage: "arrow.trianglehead.2.clockwise")
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
                onUpdate: {},
                onCheckUpdate: {},
                onSchedule: {},
                onUnschedule: {}
            )
        }
    }
}
