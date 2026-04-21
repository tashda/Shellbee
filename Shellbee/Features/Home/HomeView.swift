import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var isPermitJoinConfigPresented = false
    @State private var isPermitJoinActivePresented = false
    @State private var showingRestartAlert = false
    @State private var permitJoinStartTime: Date?
    @State private var permitJoinDuration: Int = 0
    @State private var permitJoinTargetName: String?

    private var snapshot: HomeSnapshot {
        HomeSnapshot(
            devices: environment.store.devices,
            availability: environment.store.deviceAvailability,
            states: environment.store.deviceStates,
            isConnected: environment.store.isConnected,
            isBridgeOnline: environment.store.bridgeOnline,
            groupCount: environment.store.groups.count,
            bridgeVersion: environment.store.bridgeInfo?.version,
            bridgeCommit: environment.store.bridgeInfo?.commit,
            coordinatorType: environment.store.bridgeInfo?.coordinator.type,
            coordinatorIEEEAddress: environment.store.bridgeInfo?.coordinator.ieeeAddress,
            networkChannel: environment.store.bridgeInfo?.network?.channel,
            panID: environment.store.bridgeInfo?.network?.panID,
            isPermitJoinActive: environment.store.bridgeInfo?.permitJoin ?? false,
            permitJoinEnd: environment.store.bridgeInfo?.permitJoinEnd,
            restartRequired: environment.store.bridgeInfo?.restartRequired ?? false
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.md) {
                    HomeBridgeCard(snapshot: snapshot, health: environment.store.bridgeHealth, onRestart: { showingRestartAlert = true })
                    HomeDevicesCard(snapshot: snapshot, onFilter: { environment.showDevices(filter: $0) })
                    HomeMeshCard(snapshot: snapshot, onFilter: { environment.showDevices(filter: $0) })
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(Color(.systemGroupedBackground))
            .task(id: environment.store.isConnected) {
                guard environment.store.isConnected else { return }
                environment.send(topic: Z2MTopics.Request.healthCheck, payload: .object([:]))
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PermitJoinToolbarButton(isActive: snapshot.isPermitJoinActive) {
                        if snapshot.isPermitJoinActive {
                            isPermitJoinActivePresented = true
                        } else {
                            isPermitJoinConfigPresented = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isPermitJoinConfigPresented) {
                PermitJoinSheet(devices: environment.store.devices, onConfirm: startPermitJoin)
            }
            .sheet(isPresented: $isPermitJoinActivePresented) {
                PermitJoinActiveSheet(
                    startTime: permitJoinStartTime,
                    totalDuration: permitJoinDuration,
                    targetName: permitJoinTargetName,
                    onStop: { sendPermitJoin(duration: 0, deviceName: nil) }
                )
            }
            .alert("Restart Bridge?", isPresented: $showingRestartAlert) {
                Button("Restart", role: .destructive) { environment.restartBridge() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Restarting the bridge will apply pending configuration changes and temporarily disconnect all Zigbee devices.")
            }
            .onChange(of: snapshot.isPermitJoinActive) { _, isActive in
                if !isActive {
                    permitJoinStartTime = nil
                    permitJoinDuration = 0
                    permitJoinTargetName = nil
                }
            }
        }
    }

    private func startPermitJoin(duration: Int, deviceName: String?) {
        permitJoinStartTime = Date()
        permitJoinDuration = duration
        permitJoinTargetName = deviceName?.isEmpty == false ? deviceName : nil
        sendPermitJoin(duration: duration, deviceName: deviceName)
    }

    private func sendPermitJoin(duration: Int, deviceName: String?) {
        var payload: [String: JSONValue] = ["time": .int(duration)]
        if let deviceName, !deviceName.isEmpty {
            payload["device"] = .string(deviceName)
        }
        environment.send(topic: Z2MTopics.Request.permitJoin, payload: .object(payload))
    }
}

#Preview("Loaded") {
    HomeView()
        .environment(HomeView.previewEnvironment)
}

#Preview("Empty") {
    HomeView()
        .environment(AppEnvironment())
}

private extension HomeView {
    static var previewEnvironment: AppEnvironment {
        let environment = AppEnvironment()
        environment.store.isConnected = true
        environment.store.bridgeOnline = true
        environment.store.bridgeInfo = BridgeInfo(
            version: "2.9.2",
            commit: "2b485a98c5f9c879e1e9b80ffae3c7a84b0dce8d",
            coordinator: CoordinatorInfo(type: "EmberZNet", ieeeAddress: "0x4c5bb3fffe932a84", meta: nil),
            network: NetworkInfo(channel: 20, panID: 54_074, extendedPanID: nil),
            logLevel: "info",
            permitJoin: true,
            permitJoinTimeout: 48,
            permitJoinEnd: Int(Date().timeIntervalSince1970 * 1000) + 48_000,
            restartRequired: true,
            config: nil
        )
        environment.store.groups = [Group(id: 1, friendlyName: "Living Room", members: [], scenes: [])]
        environment.store.devices = [.preview, .fallbackPreview, Device(ieeeAddress: "0x003", type: .router, networkAddress: 3, supported: false, friendlyName: "Kitchen Relay", disabled: false, definition: nil, powerSource: "mains", interviewCompleted: false, interviewing: true)]
        environment.store.deviceAvailability = [Device.preview.friendlyName: true, Device.fallbackPreview.friendlyName: false, "Kitchen Relay": true]
        environment.store.deviceStates = [
            Device.preview.friendlyName: ["battery": .int(78), "linkquality": .int(128), "update": .object(["state": .string("available")])],
            Device.fallbackPreview.friendlyName: ["battery": .int(12), "linkquality": .int(28)],
            "Kitchen Relay": ["linkquality": .int(32)]
        ]
        return environment
    }
}
