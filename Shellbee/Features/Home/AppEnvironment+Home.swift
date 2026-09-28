import Foundation

/// What Home's rows and cards read, built from every session. Shared by
/// Home and the live card previews in Settings › Home Screen.
extension AppEnvironment {
    /// One entry per saved bridge, including sessions that are reconnecting
    /// or offline, so Home can show their state. Each becomes a row.
    func homeBridgeCardEntries(selectedBridgeID: UUID?) -> [HomeBridgeCardEntry] {
        registry.orderedSessions.map { session in
            HomeBridgeCardEntry(
                id: session.bridgeID,
                name: session.displayName,
                isFocused: session.bridgeID == selectedBridgeID,
                connectionState: session.connectionState,
                isWebSocketConnected: session.store.isConnected,
                isBridgeOnline: session.store.bridgeOnline,
                info: session.store.bridgeInfo,
                health: session.store.bridgeHealth
            )
        }
    }

    func homeSnapshot(selectedBridgeID: UUID?) -> HomeSnapshot {
        // Phase 2 multi-bridge: with 2+ bridges connected, aggregate every
        // session's devices, groups, and OTA state so the Home cards show
        // totals across the user's entire network. Bridge-metadata fields
        // (version, coordinator, channel, pan id) reflect the focused bridge —
        // they're inherently per-bridge and don't aggregate cleanly. The
        // Bridge card shows "Multiple bridges" treatment in merged mode via
        // its own rendering.
        let connected = registry.sessions.values.filter(\.isConnected)
        let isMerged = connected.count >= 2

        if isMerged {
            let allDevices = connected.flatMap { $0.store.devices }
            let mergedAvailability = connected.reduce(into: [String: Bool]()) { acc, s in
                acc.merge(s.store.deviceAvailability) { existing, _ in existing }
            }
            let mergedStates = connected.reduce(into: [String: [String: JSONValue]]()) { acc, s in
                acc.merge(s.store.deviceStates) { existing, _ in existing }
            }
            let mergedOTA = connected.reduce(into: [String: OTAUpdateStatus]()) { acc, s in
                acc.merge(s.store.otaUpdates) { existing, _ in existing }
            }
            let totalGroups = connected.reduce(0) { $0 + $1.store.groups.count }
            let primary = selectedBridgeID.flatMap { registry.session(for: $0) }

            return HomeSnapshot(
                devices: allDevices,
                availability: mergedAvailability,
                states: mergedStates,
                otaStatuses: mergedOTA,
                isConnected: connected.contains { $0.store.isConnected },
                isBridgeOnline: connected.allSatisfy { $0.store.bridgeOnline },
                groupCount: totalGroups,
                bridgeVersion: primary?.store.bridgeInfo?.version,
                bridgeCommit: primary?.store.bridgeInfo?.commit,
                coordinatorType: primary?.store.bridgeInfo?.coordinator.type,
                coordinatorIEEEAddress: primary?.store.bridgeInfo?.coordinator.ieeeAddress,
                networkChannel: primary?.store.bridgeInfo?.network?.channel,
                panID: primary?.store.bridgeInfo?.network?.panID,
                isPermitJoinActive: connected.contains { $0.store.bridgeInfo?.permitJoin == true },
                permitJoinEnd: primary?.store.bridgeInfo?.permitJoinEnd,
                restartRequired: connected.contains { $0.store.bridgeInfo?.restartRequired == true }
            )
        }

        // Single-bridge / no-bridge path: read from the user's selected bridge
        // when present, otherwise present an empty snapshot so HomeView still
        // renders during cold start.
        guard let selectedBridgeID else {
            return HomeSnapshot(
                devices: [], availability: [:], states: [:],
                isConnected: false, isBridgeOnline: false, groupCount: 0,
                bridgeVersion: nil, bridgeCommit: nil,
                coordinatorType: nil, coordinatorIEEEAddress: nil,
                networkChannel: nil, panID: nil,
                isPermitJoinActive: false, permitJoinEnd: nil, restartRequired: false
            )
        }
        let store = scope(for: selectedBridgeID).store
        return HomeSnapshot(
            devices: store.devices,
            availability: store.deviceAvailability,
            states: store.deviceStates,
            otaStatuses: store.otaUpdates,
            isConnected: store.isConnected,
            isBridgeOnline: store.bridgeOnline,
            groupCount: store.groups.count,
            bridgeVersion: store.bridgeInfo?.version,
            bridgeCommit: store.bridgeInfo?.commit,
            coordinatorType: store.bridgeInfo?.coordinator.type,
            coordinatorIEEEAddress: store.bridgeInfo?.coordinator.ieeeAddress,
            networkChannel: store.bridgeInfo?.network?.channel,
            panID: store.bridgeInfo?.network?.panID,
            isPermitJoinActive: store.bridgeInfo?.permitJoin ?? false,
            permitJoinEnd: store.bridgeInfo?.permitJoinEnd,
            restartRequired: store.bridgeInfo?.restartRequired ?? false
        )
    }
}
