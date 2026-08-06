import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home, devices, groups, logs, networkMap, settings

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
        }
    }

    var supportsSearch: Bool {
        switch self {
        case .devices, .groups, .logs: true
        case .home, .networkMap, .settings: false
        }
    }
}

struct AppSearchFocusRequest: Equatable {
    var sequence = 0
    var section: AppTab?

    mutating func request(for section: AppTab) {
        guard section.supportsSearch else { return }
        sequence += 1
        self.section = section
    }
}

struct AppKeyboardActions {
    let focusSearch: () -> Void
    let selectSection: (AppTab) -> Void
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
