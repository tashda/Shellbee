import SwiftUI

enum GroupStateFilter: String, CaseIterable {
    case on = "On"
    case off = "Off"

    var systemImage: String { self == .on ? "lightbulb.fill" : "lightbulb.slash" }
}

enum GroupSceneFilter: String, CaseIterable {
    case withScenes = "With Scenes"
    case withoutScenes = "Without Scenes"

    var systemImage: String { self == .withScenes ? "sparkles" : "circle.slash" }
}

enum GroupSortOrder: String, CaseIterable {
    case name = "Name"
    case memberCount = "Members"
    case id = "Group ID"
}

@Observable
final class GroupListViewModel {
    nonisolated deinit {}

    var searchText = ""
    var sortOrder: GroupSortOrder = .id
    var sortAscending = true
    /// Multi-bridge: when set, the merged group list filters to a single
    /// bridge. Ignored in single-bridge mode.
    var bridgeFilter: UUID? = nil
    var stateFilter: GroupStateFilter?
    /// Groups with at least one member of this type.
    var memberCategory: Device.Category?
    var sceneFilter: GroupSceneFilter?
    /// Only groups without members, for tidying up.
    var emptyOnly = false

    var hasActiveFilter: Bool {
        bridgeFilter != nil || stateFilter != nil || memberCategory != nil || sceneFilter != nil || emptyOnly
    }

    func clearFilters() {
        bridgeFilter = nil
        stateFilter = nil
        memberCategory = nil
        sceneFilter = nil
        emptyOnly = false
    }

    func filteredGroups(store: AppStore) -> [Group] {
        sorted(store.groups.filter { matches($0, store: store) })
    }

    /// Search plus every filter except the bridge, which the caller applies
    /// by choosing stores.
    func matches(_ group: Group, store: AppStore) -> Bool {
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            let hit = group.friendlyName.lowercased().contains(q)
                || group.description?.lowercased().contains(q) == true
                || "\(group.id)".contains(q)
            guard hit else { return false }
        }
        return matchesFilters(group, store: store)
    }

    func matchesFilters(_ group: Group, store: AppStore,
                        ignoring ignored: PartialKeyPath<GroupListViewModel>? = nil) -> Bool {
        if ignored != \GroupListViewModel.stateFilter, let stateFilter {
            guard Self.state(of: group, store: store) == stateFilter else { return false }
        }
        if ignored != \GroupListViewModel.memberCategory, let memberCategory {
            guard Self.memberCategories(of: group, store: store).contains(memberCategory) else { return false }
        }
        if ignored != \GroupListViewModel.sceneFilter, let sceneFilter {
            guard (sceneFilter == .withScenes) == !group.scenes.isEmpty else { return false }
        }
        if ignored != \GroupListViewModel.emptyOnly, emptyOnly, !group.members.isEmpty { return false }
        return true
    }

    static func state(of group: Group, store: AppStore) -> GroupStateFilter? {
        switch store.state(for: group.friendlyName)["state"]?.stringValue?.uppercased() {
        case "ON": .on
        case "OFF": .off
        default: nil
        }
    }

    static func memberCategories(of group: Group, store: AppStore) -> Set<Device.Category> {
        let ieees = Set(group.members.map(\.ieeeAddress))
        return Set(store.devices.filter { ieees.contains($0.ieeeAddress) }.map(\.category))
    }

    func addGroup(name: String, id: Int?, environment: AppEnvironment, bridgeID: UUID?) {
        Haptics.impact(.medium)
        var payload: [String: JSONValue] = ["friendly_name": .string(name)]
        if let id { payload["id"] = .int(id) }
        // Phase 2 multi-bridge: AddGroupSheet always provides a bridgeID
        // when ≥2 bridges are connected. Single-bridge mode passes nil and
        // we resolve to the only connected session.
        guard let resolvedID = bridgeID ?? environment.registry.primaryBridgeID else { return }
        environment.send(bridge: resolvedID, topic: Z2MTopics.Request.groupAdd, payload: .object(payload))
    }

    func renameGroup(_ group: Group, to newName: String, environment: AppEnvironment, bridgeID: UUID) {
        Haptics.impact(.medium)
        environment.send(bridge: bridgeID, topic: Z2MTopics.Request.groupRename, payload: .object([
            "from": .string(group.friendlyName),
            "to": .string(newName)
        ]))
    }

    func removeGroup(_ group: Group, force: Bool, environment: AppEnvironment, bridgeID: UUID) {
        Haptics.impact(.medium)
        environment.send(bridge: bridgeID, topic: Z2MTopics.Request.groupRemove, payload: .object([
            "id": .string("\(group.id)"),
            "force": .bool(force)
        ]))
    }

    func addMember(device: Device, endpoint: Int = 1, to group: Group, environment: AppEnvironment, bridgeID: UUID) {
        Haptics.impact(.light)
        environment.send(bridge: bridgeID, topic: Z2MTopics.Request.groupMembersAdd, payload: .object([
            "group": .string("\(group.id)"),
            "device": .string(device.ieeeAddress),
            "endpoint": .int(endpoint)
        ]))
    }

    func removeMember(_ member: GroupMember, from group: Group, environment: AppEnvironment, bridgeID: UUID) {
        Haptics.impact(.light)
        environment.send(bridge: bridgeID, topic: Z2MTopics.Request.groupMembersRemove, payload: .object([
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
