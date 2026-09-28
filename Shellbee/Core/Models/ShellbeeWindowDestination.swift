import SwiftUI

/// A stable, restorable identity for every scene Shellbee can open.
///
/// Entity destinations store bridge-scoped identifiers instead of display
/// names. Group IDs and friendly names can collide across bridges, while an
/// IEEE address plus bridge ID remains unambiguous.
enum ShellbeeWindowDestination: Codable, Hashable {
    case home
    case section(AppTab)
    case device(bridgeID: UUID, ieeeAddress: String)
    case group(bridgeID: UUID, groupID: Int)
    case activity
    case log(bridgeID: UUID, entryID: UUID)
    case settings(bridgeID: UUID?)
    case networkMap(bridgeID: UUID?)

    var title: String {
        switch self {
        case .home: "Home"
        case .section(let section): section.title
        case .device: "Device"
        case .group: "Group"
        case .activity: "Activity"
        case .log: "Log Detail"
        case .settings: "Settings"
        case .networkMap: "Network Map"
        }
    }

    /// The app section that owns this destination. Every scene enters through
    /// the regular app shell so a detached detail remains navigable instead
    /// of becoming an isolated, dead-end NavigationStack.
    var rootSection: AppTab {
        switch self {
        case .home: .home
        case .section(let section): section
        case .device: .devices
        case .group: .groups
        case .activity, .log: .logs
        case .settings: .settings
        case .networkMap: .networkMap
        }
    }
}

private struct CurrentWindowDestinationKey: EnvironmentKey {
    static let defaultValue = ShellbeeWindowDestination.home
}

extension EnvironmentValues {
    var currentWindowDestination: ShellbeeWindowDestination {
        get { self[CurrentWindowDestinationKey.self] }
        set { self[CurrentWindowDestinationKey.self] = newValue }
    }
}
