import SwiftUI
import UIKit // Added import for UIKit

enum GroupSortOrder: String, CaseIterable {
    case name = "Name"
    case memberCount = "Members"
    case id = "Group ID"
}

@Observable
final class GroupListViewModel {
    var searchText = ""
    var sortOrder: GroupSortOrder = .id
    var sortAscending = true
    /// Multi-bridge: when set, the merged group list filters to a single
    /// bridge. Ignored in single-bridge mode.
    var bridgeFilter: UUID? = nil

    var hasActiveFilter: Bool {
        bridgeFilter != nil
    }

    func filteredGroups(store: AppStore) -> [Group] {
        var groups = store.groups

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            groups = groups.filter {
                $0.friendlyName.lowercased().contains(q)
                || $0.description?.lowercased().contains(q) == true
                || "\($0.id)".contains(q)
            }
        }

        return sorted(groups)
    }

    func addGroup(name: String, id: Int?, environment: AppEnvironment, bridgeID: UUID? = nil) {
        Haptics.impact(.medium)
        var payload: [String: JSONValue] = ["friendly_name": .string(name)]
        if let id { payload["id"] = .int(id) }
        if let bridgeID {
            environment.send(bridge: bridgeID, topic: Z2MTopics.Request.groupAdd, payload: .object(payload))
        } else {
            environment.send(topic: Z2MTopics.Request.groupAdd, payload: .object(payload))
        }
    }

    func renameGroup(_ group: Group, to newName: String, environment: AppEnvironment) {
        Haptics.impact(.medium)
        environment.send(topic: Z2MTopics.Request.groupRename, payload: .object([
            "from": .string(group.friendlyName),
            "to": .string(newName)
        ]))
    }

    func removeGroup(_ group: Group, force: Bool, environment: AppEnvironment) {
        Haptics.impact(.medium)
        environment.send(topic: Z2MTopics.Request.groupRemove, payload: .object([
            "id": .string("\(group.id)"),
            "force": .bool(force)
        ]))
    }

    func addMember(device: Device, endpoint: Int = 1, to group: Group, environment: AppEnvironment) {
        Haptics.impact(.light)
        environment.send(topic: Z2MTopics.Request.groupMembersAdd, payload: .object([
            "group": .string("\(group.id)"),
            "device": .string(device.ieeeAddress),
            "endpoint": .int(endpoint)
        ]))
    }

    func removeMember(_ member: GroupMember, from group: Group, environment: AppEnvironment) {
        Haptics.impact(.light)
        environment.send(topic: Z2MTopics.Request.groupMembersRemove, payload: .object([
            "device": .string(member.ieeeAddress),
            "endpoint": .int(member.endpoint),
            "group": .string("\(group.id)")
        ]))
    }

    private func sorted(_ groups: [Group]) -> [Group] {
        groups.sorted { a, b in
            let result: Bool
            switch sortOrder {
            case .name:
                result = a.friendlyName.localizedCompare(b.friendlyName) == .orderedAscending
            case .memberCount:
                result = a.members.count > b.members.count
            case .id:
                result = a.id < b.id
            }
            return sortAscending ? result : !result
        }
    }
}
