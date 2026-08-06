import Foundation

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

    var rootSection: AppTab? {
        switch self {
        case .home: .home
        case .section(let section): section
        default: nil
        }
    }
}
