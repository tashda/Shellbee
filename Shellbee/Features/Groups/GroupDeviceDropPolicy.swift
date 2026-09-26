import Foundation

nonisolated struct GroupMemberAddRequest: Equatable {
    let bridgeID: UUID
    let groupID: Int
    let ieeeAddress: String
    let endpoint: Int

    @MainActor
    var topic: String { Z2MTopics.Request.groupMembersAdd }

    @MainActor
    var payload: JSONValue {
        .object([
            "group": .string("\(groupID)"),
            "device": .string(ieeeAddress),
            "endpoint": .int(endpoint)
        ])
    }
}

nonisolated enum GroupDeviceDropOutcome: Equatable {
    case request(GroupMemberAddRequest, deviceName: String)
    case alreadyMember(deviceName: String)
    case rejected(reason: String)
}

nonisolated struct GroupDeviceDropCandidate {
    let ieeeAddress: String
    let name: String
    let isCoordinator: Bool
    let endpoint: Int
}

/// Pure decision logic. Its value-only input keeps policy tests independent of
/// SwiftUI's default MainActor isolation and XCTest's actor bridge on Xcode 26.
nonisolated enum GroupDeviceDropDecision {
    static func evaluate(
        sourceBridgeID: UUID?,
        targetBridgeID: UUID,
        draggedIEEEAddress: String,
        targetGroupID: Int,
        targetGroupMembers: Set<String>,
        availableDevice: GroupDeviceDropCandidate?
    ) -> GroupDeviceDropOutcome {
        guard let sourceBridgeID else {
            return .rejected(reason: "The dragged device does not identify its source bridge.")
        }
        guard sourceBridgeID == targetBridgeID else {
            return .rejected(reason: "Devices can only be added to groups on the same bridge.")
        }
        guard let device = availableDevice,
              device.ieeeAddress == draggedIEEEAddress,
              !device.isCoordinator else {
            return .rejected(reason: "This device is no longer available on the target bridge.")
        }
        guard !targetGroupMembers.contains(device.ieeeAddress) else {
            return .alreadyMember(deviceName: device.name)
        }

        return .request(
            GroupMemberAddRequest(
                bridgeID: targetBridgeID,
                groupID: targetGroupID,
                ieeeAddress: device.ieeeAddress,
                endpoint: device.endpoint
            ),
            deviceName: device.name
        )
    }
}

@MainActor
enum GroupDeviceDropPolicy {
    static func evaluate(
        _ payload: DeviceTransferPayload,
        targetGroup: Group,
        targetBridgeID: UUID,
        availableDevices: [Device]
    ) -> GroupDeviceDropOutcome {
        let device = availableDevices.first(where: {
            $0.ieeeAddress == payload.ieeeAddress && $0.type != .coordinator
        })
        let candidate = device.map {
            GroupDeviceDropCandidate(
                ieeeAddress: $0.ieeeAddress,
                name: $0.friendlyName,
                isCoordinator: $0.type == .coordinator,
                endpoint: $0.availableEndpoints.first ?? 1
            )
        }

        return GroupDeviceDropDecision.evaluate(
            sourceBridgeID: payload.bridgeID,
            targetBridgeID: targetBridgeID,
            draggedIEEEAddress: payload.ieeeAddress,
            targetGroupID: targetGroup.id,
            targetGroupMembers: Set(targetGroup.members.map(\.ieeeAddress)),
            availableDevice: candidate
        )
    }
}
