import SwiftUI

struct TouchlinkDeviceRow: View {
    let device: TouchlinkDevice
    let knownName: String?
    let identifyInProgress: Bool
    let resetInProgress: Bool
    let onIdentify: (TouchlinkDevice) -> Void
    let onReset: (TouchlinkDevice) -> Void

    @State private var showResetConfirmation = false

    private var busy: Bool { identifyInProgress || resetInProgress }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                if let name = knownName {
                    Text(name)
                        .font(.body)
                    Text(device.ieeeAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                } else {
                    Text(device.ieeeAddress)
                        .font(.body)
                        .monospaced()
                }
                Text("Channel \(device.channel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    onIdentify(device)
                } label: {
                    SwiftUI.Group {
                        if identifyInProgress {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "exclamationmark.triangle")
                        }
                    }
                    .frame(width: DesignTokens.Size.touchlinkButtonFrame, height: DesignTokens.Size.touchlinkButtonFrame)
                }
                .buttonStyle(.bordered)
                .disabled(busy)

                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    SwiftUI.Group {
                        if resetInProgress {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                    .frame(width: DesignTokens.Size.touchlinkButtonFrame, height: DesignTokens.Size.touchlinkButtonFrame)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(busy)
            }
        }
        .alert("Factory Reset \(knownName ?? device.ieeeAddress)?", isPresented: $showResetConfirmation) {
            Button("Factory Reset", role: .destructive) { onReset(device) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset the device to factory defaults over Touchlink.")
        }
    }
}

#Preview {
    List {
        TouchlinkDeviceRow(
            device: TouchlinkDevice(ieeeAddress: "0x00158d0001234567", channel: 15),
            knownName: "Living Room Bulb",
            identifyInProgress: false,
            resetInProgress: false,
            onIdentify: { _ in },
            onReset: { _ in }
        )
        TouchlinkDeviceRow(
            device: TouchlinkDevice(ieeeAddress: "0x00158d0007654321", channel: 11),
            knownName: nil,
            identifyInProgress: true,
            resetInProgress: false,
            onIdentify: { _ in },
            onReset: { _ in }
        )
    }
}
