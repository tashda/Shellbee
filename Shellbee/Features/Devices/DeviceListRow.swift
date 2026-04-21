import SwiftUI

struct DeviceListRow: View {
    let device: Device
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?
    let onRename: () -> Void
    let onRemove: () -> Void
    let onReconfigure: () -> Void
    let onInterview: () -> Void
    let onUpdate: (() -> Void)?
    let onCheckUpdate: () -> Void

    var body: some View {
        NavigationLink(value: device) {
            DeviceRowView(device: device, state: state, isAvailable: isAvailable, otaStatus: otaStatus)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if let onUpdate {
                Button(action: onUpdate) {
                    swipeActionLabel("Update", systemImage: "arrow.up.circle")
                }
                .tint(.blue)
            } else {
                Button(action: onCheckUpdate) {
                    swipeActionLabel("Check", systemImage: "arrow.trianglehead.2.clockwise")
                }
                .tint(.blue)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onRemove) {
                swipeActionLabel("Delete", systemImage: "trash")
            }
            Button(action: onRename) {
                swipeActionLabel("Rename", systemImage: "pencil")
            }
            .tint(.orange)
            Button(action: onReconfigure) {
                swipeActionLabel("Config", systemImage: "gearshape")
            }
            .tint(.gray)
            Button(action: onInterview) {
                swipeActionLabel("Interview", systemImage: "questionmark.circle")
            }
            .tint(.purple)
            if let onUpdate {
                Button(action: onUpdate) {
                    swipeActionLabel("Update", systemImage: "arrow.up.circle")
                }
                .tint(.blue)
            }
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

    private func swipeActionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: DesignTokens.Size.metricSymbol - 2, weight: .semibold))
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(minWidth: DesignTokens.Size.deviceActionSheetImage)
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
