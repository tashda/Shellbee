import SwiftUI

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var isPermitJoinConfigPresented = false
    @State private var isPermitJoinActivePresented = false
    @State private var showingRestartAlert = false
    @State private var permitJoinStartTime: Date?
    @State private var permitJoinDuration: Int = 0
    @State private var permitJoinTargetName: String?
    @State private var showingMeshDetail = false

    @AppStorage(HomeSettings.recentEventsCountKey) private var recentEventsCount: Int = HomeSettings.recentEventsCountDefault
    @State private var showingAllLogs = false
    @State private var layout = HomeLayoutStore()

    private var snapshot: HomeSnapshot {
        HomeSnapshot(
            devices: environment.store.devices,
            availability: environment.store.deviceAvailability,
            states: environment.store.deviceStates,
            otaStatuses: environment.store.otaUpdates,
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
            List {
                Section {
                    ForEach(layout.visibleOrder) { id in
                        HomeCardSlot(
                            card: id,
                            isEditing: layout.isEditing,
                            onHide: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    layout.hide(id)
                                }
                            },
                            onEnterEdit: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    layout.isEditing = true
                                }
                            }
                        ) {
                            cardView(for: id)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: DesignTokens.Spacing.sm,
                            leading: DesignTokens.Spacing.lg,
                            bottom: DesignTokens.Spacing.sm,
                            trailing: DesignTokens.Spacing.lg
                        ))
                    }
                    .onMove { source, destination in
                        layout.move(from: source, to: destination)
                    }
                }

                if layout.isEditing && !layout.hidden.isEmpty {
                    Section {
                        HomeAddCardsSection(
                            hidden: HomeCardID.allCases.filter { layout.hidden.contains($0) }
                        ) { card in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                layout.show(card)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: DesignTokens.Spacing.md,
                            leading: DesignTokens.Spacing.lg,
                            bottom: DesignTokens.Spacing.lg,
                            trailing: DesignTokens.Spacing.lg
                        ))
                    }
                }

                if layout.visibleOrder.isEmpty {
                    emptyLayoutState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(layout.isEditing ? .active : .inactive))
            .background(HomeBackgroundGradient().ignoresSafeArea())
            .navigationDestination(isPresented: $showingAllLogs) {
                LogsView()
            }
            .navigationDestination(isPresented: $showingMeshDetail) {
                MeshDetailView(snapshot: snapshot)
            }
            .task(id: environment.store.isConnected) {
                guard environment.store.isConnected else { return }
                environment.send(topic: Z2MTopics.Request.healthCheck, payload: .object([:]))
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if layout.isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                layout.isEditing = false
                            }
                        }
                        .fontWeight(.semibold)
                    }
                } else {
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

    @ViewBuilder
    private func cardView(for id: HomeCardID) -> some View {
        switch id {
        case .bridge:
            HomeBridgeCard(
                snapshot: snapshot,
                health: environment.store.bridgeHealth,
                serverName: environment.connectionConfig?.name,
                connectionState: environment.connectionState,
                onRestart: { showingRestartAlert = true }
            )
        case .devices:
            HomeDevicesCard(snapshot: snapshot) {
                environment.showDevices(filter: .all)
            } onFilter: {
                environment.showDevices(filter: $0)
            }
        case .groups:
            HomeGroupsCard(count: environment.store.groups.count) {
                environment.selectedTab = .groups
            }
        case .mesh:
            HomeMeshCard(snapshot: snapshot) {
                showingMeshDetail = true
            } onFilter: {
                environment.showDevices(filter: $0)
            }
        case .recentEvents:
            HomeLogsCard(
                entries: Array(environment.store.logEntries.prefix(recentEventsCount)),
                onOpenEntry: { entry in
                    environment.pendingLogSheet = LogSheetRequest(entryIDs: [entry.id])
                },
                onOpenAll: { showingAllLogs = true }
            )
        }
    }

    private var emptyLayoutState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "square.grid.2x2")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No cards shown")
                .font(.headline)
            Text("All cards have been hidden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Edit Home") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    layout.isEditing = true
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xxl)
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
