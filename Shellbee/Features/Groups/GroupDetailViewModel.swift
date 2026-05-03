import Foundation
import UIKit

@Observable
final class GroupDetailViewModel {
    func synthesizedState(for group: Group, environment: AppEnvironment, bridgeID: UUID) -> [String: JSONValue] {
        let scope = environment.scope(for: bridgeID)
        let memberStates = group.members.compactMap { member in
            scope.store.devices.first { $0.ieeeAddress == member.ieeeAddress }
                .map { scope.store.state(for: $0.friendlyName) }
        }
        guard !memberStates.isEmpty else { return [:] }

        var result: [String: JSONValue] = [:]

        if memberStates.contains(where: { $0["state"] != nil }) {
            let anyOn = memberStates.contains { $0["state"]?.stringValue == "ON" }
            result["state"] = .string(anyOn ? "ON" : "OFF")
        }

        let brightnessValues = memberStates.compactMap { $0["brightness"]?.numberValue }
        if !brightnessValues.isEmpty {
            result["brightness"] = .int(Int((brightnessValues.reduce(0, +) / Double(brightnessValues.count)).rounded()))
        }

        let colorTempValues = memberStates.compactMap { $0["color_temp"]?.numberValue }
        if !colorTempValues.isEmpty {
            result["color_temp"] = .int(Int((colorTempValues.reduce(0, +) / Double(colorTempValues.count)).rounded()))
        }

        if let colorMode = memberStates.compactMap({ $0["color_mode"]?.stringValue }).first {
            result["color_mode"] = .string(colorMode)
        }

        return result
    }

    func addMembers(_ selections: [(device: Device, endpoint: Int)], to group: Group, environment: AppEnvironment, bridgeID: UUID) {
        Haptics.impact(.medium)
        let scope = environment.scope(for: bridgeID)
        for selection in selections {
            scope.send(topic: Z2MTopics.Request.groupMembersAdd, payload: .object([
                "group": .string("\(group.id)"),
                "device": .string(selection.device.ieeeAddress),
                "endpoint": .int(selection.endpoint)
            ]))
        }
    }

    func removeMember(_ member: GroupMember, from group: Group, environment: AppEnvironment, bridgeID: UUID) {
        Haptics.impact(.light)
        environment.scope(for: bridgeID).send(topic: Z2MTopics.Request.groupMembersRemove, payload: .object([
            "device": .string(member.ieeeAddress),
            "endpoint": .int(member.endpoint),
            "group": .string("\(group.id)")
        ]))
    }

    func recallScene(_ scene: Z2MScene, in group: Group, environment: AppEnvironment, bridgeID: UUID) {
        Haptics.impact(.medium)
        environment.scope(for: bridgeID).send(
            topic: Z2MTopics.deviceSet(group.friendlyName),
            payload: .object(["scene_recall": .int(scene.id)])
        )
    }

    func addScene(name: String, in group: Group, environment: AppEnvironment, bridgeID: UUID) {
        Haptics.impact(.medium)
        let nextID = (group.scenes.map(\.id).max() ?? -1) + 1
        environment.scope(for: bridgeID).send(
            topic: Z2MTopics.deviceSet(group.friendlyName),
            payload: .object(["scene_add": .object(["ID": .int(nextID), "name": .string(name)])])
        )
    }

    func removeScene(_ scene: Z2MScene, from group: Group, environment: AppEnvironment, bridgeID: UUID) {
        Haptics.impact(.light)
        environment.scope(for: bridgeID).send(
            topic: Z2MTopics.deviceSet(group.friendlyName),
            payload: .object(["scene_remove": .int(scene.id)])
        )
    }
}
