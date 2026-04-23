import SwiftUI

struct DeviceListRow: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?
    var checkResult: AppStore.DeviceCheckResult? = nil
    let onRename: () -> Void
    let onRemove: () -> Void
    let onReconfigure: () -> Void
    let onInterview: () -> Void
    let onUpdate: (() -> Void)?
    let onCheckUpdate: () -> Void

    private var isCheckingOrUpdating: Bool {
        otaStatus?.isActive == true
    }

    var body: some View {
        NavigationLink(value: device) {
            DeviceRowView(device: device, state: state, isAvailable: isAvailable, otaStatus: otaStatus, checkResult: checkResult)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isCheckingOrUpdating {
                Button(action: onCheckUpdate) {
                    Label("Check", systemImage: "arrow.trianglehead.2.clockwise")
                }
                .tint(.blue)
            }
            if let onUpdate, !isCheckingOrUpdating {
                Button(action: onUpdate) {
                    Label("Update", systemImage: "arrow.up.circle")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onRemove) {
                Label("Delete", systemImage: "trash")
            }
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
            if let onUpdate {
                Button(action: onUpdate) {
                    Label("Update Firmware", systemImage: "arrow.up.circle")
                }
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("Remove Device", systemImage: "trash")
            }
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
                onCheckUpdate: {}
            )
        }
    }
}
