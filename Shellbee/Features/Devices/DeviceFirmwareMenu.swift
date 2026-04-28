import SwiftUI

struct DeviceFirmwareMenu: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showUpdateAllConfirm = false

    private var otaCapableDevices: [Device] {
        environment.store.devices.filter {
            guard $0.definition?.supportsOTA == true else { return false }
            // Exclude devices currently being checked or updated — Z2M rejects
            // a concurrent check for an already-checking device.
            return environment.store.otaStatus(for: $0.friendlyName)?.isActive != true
        }
    }

    private var devicesWithUpdateAvailable: [Device] {
        environment.store.devices.filter {
            environment.store.state(for: $0.friendlyName).hasUpdateAvailable
        }
    }

    var body: some View {
        let otaCount = otaCapableDevices.count
        let updateCount = devicesWithUpdateAvailable.count
        let bulkProgress = environment.otaBulkQueue.progress
        let bulkActive = bulkProgress != nil
        Menu {
            if let progress = bulkProgress {
                let kindLabel = progress.kind == .check ? "Checking" : "Updating"
                Section {
                    Text("\(kindLabel) \(progress.completed) of \(progress.total)")
                    Button(role: .destructive) {
                        environment.otaBulkQueue.cancelAll()
                    } label: {
                        Label("Cancel", systemImage: "stop.circle")
                    }
                }
                Divider()
            }

            Button {
                // Z2M only offers a synchronous OTA check; there is no
                // "scheduled check". Route every OTA-capable device through
                // the rate-limited bulk queue regardless of power source —
                // sleepy battery devices that happen to be awake succeed,
                // ones that don't respond surface the standard "Device
                // didn't respond to OTA" error, same as windfront.
                let names = otaCapableDevices.map(\.friendlyName)
                for name in names {
                    environment.store.startOTACheck(for: name)
                }
                environment.otaBulkQueue.enqueue(names, kind: .check)
            } label: {
                Label("Check All for Updates\(otaCount > 0 ? " (\(otaCount))" : "")", systemImage: "arrow.trianglehead.2.clockwise")
            }
            .disabled(otaCount == 0 || bulkActive)

            Button {
                showUpdateAllConfirm = true
            } label: {
                Label(
                    updateCount > 0 ? "Update All Available (\(updateCount))" : "No Updates",
                    systemImage: updateCount > 0 ? "arrow.up.circle" : "checkmark.circle"
                )
            }
            .disabled(updateCount == 0 || bulkActive)
        } label: {
            ZStack(alignment: .topTrailing) {
                if bulkActive {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle")
                }
                if updateCount > 0 && !bulkActive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: DesignTokens.Size.logLevelDotSize, height: DesignTokens.Size.logLevelDotSize)
                        .offset(x: 4, y: -2)
                }
            }
        }
        .accessibilityLabel("Firmware updates")
        .alert(
            "Update \(updateCount) device\(updateCount == 1 ? "" : "s")?",
            isPresented: $showUpdateAllConfirm
        ) {
            Button("Update All", role: .destructive) {
                let names = devicesWithUpdateAvailable.map(\.friendlyName)
                for name in names {
                    environment.store.startOTAUpdate(for: name)
                }
                environment.otaBulkQueue.enqueue(names, kind: .update)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Firmware updates run sequentially and can take several minutes per device. Devices may be briefly unresponsive during their update.")
        }
    }
}
