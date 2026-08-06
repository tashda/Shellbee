import Foundation

enum CommandPaletteCategory: String, CaseIterable, Hashable {
    case navigation = "Navigation"
    case devices = "Devices"
    case groups = "Groups"
    case bridgeActions = "Bridge Actions"
    case networkMap = "Network Map"

    var sortOrder: Int {
        Self.allCases.firstIndex(of: self) ?? Self.allCases.count
    }
}

enum CommandPaletteAction: Hashable {
    case navigate(AppTab)
    case openDevice(DeviceRoute)
    case openGroup(GroupRoute)
    case identify(bridgeID: UUID, friendlyName: String)
    case checkOTA(bridgeID: UUID, friendlyName: String)
    case setPermitJoin(bridgeID: UUID, enabled: Bool)
    case refreshBridge(UUID)
    case openDiagnostics(UUID)
    case openNetworkMap(UUID)
    case refreshNetworkMap(UUID)
}

struct CommandPaletteItem: Identifiable, Hashable {
    let action: CommandPaletteAction
    let category: CommandPaletteCategory
    let title: String
    let subtitle: String?
    let systemImage: String
    let keywords: [String]
    let disabledReason: String?
    let requiresConfirmation: Bool

    var id: CommandPaletteAction { action }
    var isEnabled: Bool { disabledReason == nil }

    var accessibilityLabel: String {
        [category.rawValue, title, subtitle, disabledReason]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

struct CommandPaletteBridge: Hashable {
    let id: UUID
    let name: String
    let isConnected: Bool
    let isPermitJoinOpen: Bool
}

struct CommandPaletteModel {
    let items: [CommandPaletteItem]

    init(
        bridges: [CommandPaletteBridge],
        devices: [BridgeBoundDevice],
        groups: [BridgeBoundGroup]
    ) {
        var result = Self.navigationItems
        result += Self.deviceItems(devices, bridges: bridges)
        result += Self.groupItems(groups, bridges: bridges)
        result += Self.bridgeItems(bridges)
        items = result
    }

    func results(matching query: String) -> [CommandPaletteItem] {
        let normalized = Self.normalize(query)
        guard !normalized.isEmpty else {
            return items.sorted(by: Self.defaultOrder)
        }

        return items.compactMap { item -> (CommandPaletteItem, Int)? in
            guard let score = Self.score(item, query: normalized) else { return nil }
            return (item, score)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return Self.defaultOrder(lhs.0, rhs.0)
        }
        .map(\.0)
    }

    private static var navigationItems: [CommandPaletteItem] {
        AppTab.keyboardSections.map { section in
            CommandPaletteItem(
                action: .navigate(section),
                category: .navigation,
                title: section.title,
                subtitle: nil,
                systemImage: section.systemImage,
                keywords: ["go", "open", "section"],
                disabledReason: nil,
                requiresConfirmation: false
            )
        }
    }

    private static func deviceItems(
        _ devices: [BridgeBoundDevice],
        bridges: [CommandPaletteBridge]
    ) -> [CommandPaletteItem] {
        let connectedIDs = Set(bridges.filter(\.isConnected).map(\.id))
        return devices.flatMap { bound in
            let route = DeviceRoute(bridgeID: bound.bridgeID, device: bound.device)
            let unavailable = connectedIDs.contains(bound.bridgeID) ? nil : "Bridge is disconnected"
            let identifyUnavailable = unavailable
                ?? (bound.device.supportsIdentify ? nil : "Identify is not supported")
            let otaUnavailable = unavailable
                ?? (bound.device.definition?.supportsOTA == true ? nil : "OTA is not supported")
            return [
                CommandPaletteItem(
                    action: .openDevice(route), category: .devices,
                    title: bound.device.friendlyName, subtitle: bound.bridgeName,
                    systemImage: "sensor.tag.radiowaves.forward.fill",
                    keywords: [bound.device.ieeeAddress, "device", "open"],
                    disabledReason: unavailable, requiresConfirmation: false
                ),
                CommandPaletteItem(
                    action: .identify(bridgeID: bound.bridgeID, friendlyName: bound.device.friendlyName),
                    category: .devices, title: "Identify \(bound.device.friendlyName)",
                    subtitle: bound.bridgeName, systemImage: "wave.3.right.circle",
                    keywords: [bound.device.ieeeAddress, "device"],
                    disabledReason: identifyUnavailable, requiresConfirmation: false
                ),
                CommandPaletteItem(
                    action: .checkOTA(bridgeID: bound.bridgeID, friendlyName: bound.device.friendlyName),
                    category: .devices, title: "Check OTA for \(bound.device.friendlyName)",
                    subtitle: bound.bridgeName, systemImage: "arrow.down.circle",
                    keywords: [bound.device.ieeeAddress, "firmware", "update"],
                    disabledReason: otaUnavailable, requiresConfirmation: true
                )
            ]
        }
    }

    private static func groupItems(
        _ groups: [BridgeBoundGroup],
        bridges: [CommandPaletteBridge]
    ) -> [CommandPaletteItem] {
        let connectedIDs = Set(bridges.filter(\.isConnected).map(\.id))
        return groups.map { bound in
            CommandPaletteItem(
                action: .openGroup(GroupRoute(bridgeID: bound.bridgeID, group: bound.group)),
                category: .groups, title: bound.group.friendlyName,
                subtitle: bound.bridgeName, systemImage: "square.on.square.fill",
                keywords: ["group", "open"],
                disabledReason: connectedIDs.contains(bound.bridgeID) ? nil : "Bridge is disconnected",
                requiresConfirmation: false
            )
        }
    }

    private static func bridgeItems(_ bridges: [CommandPaletteBridge]) -> [CommandPaletteItem] {
        bridges.flatMap { bridge in
            let unavailable = bridge.isConnected ? nil : "Bridge is disconnected"
            let permitTitle = bridge.isPermitJoinOpen ? "Close Permit Join" : "Open Permit Join"
            return [
                CommandPaletteItem(
                    action: .setPermitJoin(bridgeID: bridge.id, enabled: !bridge.isPermitJoinOpen),
                    category: .bridgeActions, title: permitTitle, subtitle: bridge.name,
                    systemImage: bridge.isPermitJoinOpen ? "lock.fill" : "lock.open",
                    keywords: ["pairing", "join"], disabledReason: unavailable,
                    requiresConfirmation: !bridge.isPermitJoinOpen
                ),
                CommandPaletteItem(
                    action: .refreshBridge(bridge.id), category: .bridgeActions,
                    title: "Refresh Bridge Data", subtitle: bridge.name,
                    systemImage: "arrow.clockwise", keywords: ["devices", "groups"],
                    disabledReason: unavailable, requiresConfirmation: false
                ),
                CommandPaletteItem(
                    action: .openDiagnostics(bridge.id), category: .bridgeActions,
                    title: "Open Diagnostics", subtitle: bridge.name,
                    systemImage: "stethoscope", keywords: ["settings", "health"],
                    disabledReason: nil, requiresConfirmation: false
                ),
                CommandPaletteItem(
                    action: .openNetworkMap(bridge.id), category: .networkMap,
                    title: "Open Network Map", subtitle: bridge.name,
                    systemImage: AppTab.networkMap.systemImage, keywords: ["topology", "mesh"],
                    disabledReason: unavailable, requiresConfirmation: false
                ),
                CommandPaletteItem(
                    action: .refreshNetworkMap(bridge.id), category: .networkMap,
                    title: "Refresh Network Map", subtitle: bridge.name,
                    systemImage: "arrow.clockwise", keywords: ["topology", "mesh"],
                    disabledReason: unavailable, requiresConfirmation: true
                )
            ]
        }
    }

    private static func score(_ item: CommandPaletteItem, query: String) -> Int? {
        let title = normalize(item.title)
        let subtitle = normalize(item.subtitle ?? "")
        let keywords = normalize(item.keywords.joined(separator: " "))
        if title == query { return 0 }
        if title.hasPrefix(query) { return 10 }
        if title.split(separator: " ").contains(where: { $0.hasPrefix(query) }) { return 20 }
        if title.contains(query) { return 30 }
        if subtitle.contains(query) { return 40 }
        if keywords.contains(query) { return 50 }
        return nil
    }

    private static func defaultOrder(_ lhs: CommandPaletteItem, _ rhs: CommandPaletteItem) -> Bool {
        if lhs.category.sortOrder != rhs.category.sortOrder {
            return lhs.category.sortOrder < rhs.category.sortOrder
        }
        if lhs.title != rhs.title {
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return (lhs.subtitle ?? "").localizedStandardCompare(rhs.subtitle ?? "") == .orderedAscending
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
