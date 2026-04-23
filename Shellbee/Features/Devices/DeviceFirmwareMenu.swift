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
                Label("Update All Available\(updateCount > 0 ? " (\(updateCount))" : "")", systemImage: "arrow.up.circle")
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
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -2)
                }
            }
        }
        .accessibilityLabel("Firmware updates")
        .confirmationDialog(
            "Update \(updateCount) device\(updateCount == 1 ? "" : "s")?",
            isPresented: $showUpdateAllConfirm,
            titleVisibility: .visible
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
