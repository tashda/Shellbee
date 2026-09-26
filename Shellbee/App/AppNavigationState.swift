import SwiftUI

enum AppTab: String, Codable, Hashable, CaseIterable {
    case home, devices, groups, logs, networkMap, settings, search

    static let keyboardSections: [AppTab] = [
        .home, .devices, .groups, .logs, .networkMap, .settings
    ]

    var title: String {
        switch self {
        case .home: "Home"
        case .devices: "Devices"
        case .groups: "Groups"
        case .logs: "Activity"
        case .networkMap: "Network Map"
        case .settings: "Settings"
        case .search: "Search"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .devices: "sensor.tag.radiowaves.forward.fill"
        case .groups: "square.on.square.fill"
        case .logs: "list.bullet.rectangle"
        case .networkMap: "point.3.connected.trianglepath.dotted"
        case .settings: "gearshape.fill"
        case .search: "magnifyingglass"
        }
    }

    /// Navigation icon as it should actually be drawn. Tabs get a custom
    /// symbol from `Assets.xcassets/Custom Icons/Navigation` one at a time as
    /// they're designed and approved; everything else falls back to its
    /// current SF Symbol until it has one.
    var symbol: ShellbeeSymbol {
        switch self {
        case .home: .custom("home")
        case .devices: .custom("devices")
        case .groups: .custom("groups")
        case .logs: .custom("activity")
        case .networkMap: .custom("mesh")
        case .settings: .custom("settings")
        case .search: .custom("search")
        }
    }
}

struct AppKeyboardActions {
    let focusSearch: () -> Void
    let selectSection: (AppTab) -> Void
    let showCommandPalette: () -> Void
}

private struct AppKeyboardActionsKey: FocusedValueKey {
    typealias Value = AppKeyboardActions
}

extension FocusedValues {
    var appKeyboardActions: AppKeyboardActions? {
        get { self[AppKeyboardActionsKey.self] }
        set { self[AppKeyboardActionsKey.self] = newValue }
    }
}

enum DeviceQuickFilter: Hashable {
    case all
    case online
    case offline
    case availabilityOff
    case batteryLow
    case weakSignal
    case interviewing
    case unsupported
    case updatesAvailable
    case router
    case endDevice
}
