import Foundation

struct GroupMemberAddRequest: Equatable {
    let bridgeID: UUID
    let groupID: Int
    let ieeeAddress: String
    let endpoint: Int

    var topic: String { Z2MTopics.Request.groupMembersAdd }

    var payload: JSONValue {
        .object([
            "group": .string("\(groupID)"),
            "device": .string(ieeeAddress),
            "endpoint": .int(endpoint)
        ])
    }
}

enum GroupDeviceDropOutcome: Equatable {
    case request(GroupMemberAddRequest, deviceName: String)
    case alreadyMember(deviceName: String)
    case rejected(reason: String)
}

enum GroupDeviceDropPolicy {
    static func evaluate(
        _ payload: DeviceTransferPayload,
        targetGroup: Group,
        targetBridgeID: UUID,
        availableDevices: [Device]
    ) -> GroupDeviceDropOutcome {
        guard let sourceBridgeID = payload.bridgeID else {
            return .rejected(reason: "The dragged device does not identify its source bridge.")
        }
        guard sourceBridgeID == targetBridgeID else {
            return .rejected(reason: "Devices can only be added to groups on the same bridge.")
        }
        guard let device = availableDevices.first(where: {
            $0.ieeeAddress == payload.ieeeAddress && $0.type != .coordinator
        }) else {
            return .rejected(reason: "This device is no longer available on the target bridge.")
        }
        if targetGroup.members.contains(where: { $0.ieeeAddress == device.ieeeAddress }) {
            return .alreadyMember(deviceName: device.friendlyName)
        }

        return .request(
            GroupMemberAddRequest(
                bridgeID: targetBridgeID,
                groupID: targetGroup.id,
                ieeeAddress: device.ieeeAddress,
                endpoint: device.availableEndpoints.first ?? 1
            ),
            deviceName: device.friendlyName
        )
    }
}
