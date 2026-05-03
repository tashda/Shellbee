import SwiftUI

struct DeviceFirmwareMenu: View {
    /// Phase 1 multi-bridge: the bridge whose devices the menu acts on. The
    /// list view passes either the only connected bridge (single-bridge),
    /// the user-selected filter bridge (merged + filtered), or the focused
    /// bridge (merged + no filter). Nil hides the menu — there's no sensible
    /// "all bridges" semantic for the bulk OTA queue today.
    let bridgeID: UUID
    @Environment(AppEnvironment.self) private var environment
    @State private var showUpdateAllConfirm = false

    private var scope: BridgeScope { environment.scope(for: bridgeID) }
    private var queue: OTABulkOperationQueue? { environment.otaBulkQueue(for: bridgeID) }

    private var otaCapableDevices: [Device] {
        scope.store.devices.filter {
            guard $0.definition?.supportsOTA == true else { return false }
            // Exclude devices currently being checked or updated — Z2M rejects
            // a concurrent check for an already-checking device.
            return scope.store.otaStatus(for: $0.friendlyName)?.isActive != true
        }
    }

    private var devicesWithUpdateAvailable: [Device] {
        scope.store.devices.filter {
            scope.store.state(for: $0.friendlyName).hasUpdateAvailable
        }
    }

    var body: some View {
        let otaCount = otaCapableDevices.count
        let updateCount = devicesWithUpdateAvailable.count
        let bulkProgress = queue?.progress
        let bulkActive = bulkProgress != nil
        Menu {
            if let progress = bulkProgress {
                let kindLabel = progress.kind == .check ? "Checking" : "Updating"
                Section {
                    Text("\(kindLabel) \(progress.completed) of \(progress.total)")
                    Button(role: .destructive) {
                        queue?.cancelAll()
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
                    scope.store.startOTACheck(for: name)
                }
                queue?.enqueue(names, kind: .check)
            } label: {
                Label("Check All for Updates\(otaCount > 0 ? " (\(otaCount))" : "")", systemImage: "arrow.triangle.2.circlepath")
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
                } else {
                    Image(systemName: "arrow.up.circle")
                }
                if updateCount > 0 && !bulkActive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: DesignTokens.Size.logLevelDotSize, height: DesignTokens.Size.logLevelDotSize)
                        .offset(x: DesignTokens.Size.firmwareUpdateBadgeOffsetX,
                                y: DesignTokens.Size.firmwareUpdateBadgeOffsetY)
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
                    scope.store.startOTAUpdate(for: name)
                }
                queue?.enqueue(names, kind: .update)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Firmware updates run sequentially and can take several minutes per device. Devices may be briefly unresponsive during their update.")
        }
    }
}
