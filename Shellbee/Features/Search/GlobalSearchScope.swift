import SwiftUI

/// The filter bubbles shown above global search results. `.all` mixes every
/// category into sections; the others narrow results to one kind.
enum GlobalSearchScope: String, CaseIterable, Identifiable, Hashable {
    case all
    case devices
    case groups
    case bridges
    case activity
    case logs
    case docs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .devices: "Devices"
        case .groups: "Groups"
        case .bridges: "Bridges"
        case .activity: "Activity"
        case .logs: "Log"
        case .docs: "Device Library"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .devices: AppTab.devices.systemImage
        case .groups: AppTab.groups.systemImage
        case .bridges: "antenna.radiowaves.left.and.right"
        case .activity: "list.bullet.rectangle"
        case .logs: "text.alignleft"
        case .docs: "books.vertical.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: .accentColor
        case .devices: .orange
        case .groups: .green
        case .bridges: .teal
        case .activity: .purple
        case .logs: .indigo
        case .docs: .brown
        }
    }

    /// Every scope except `.all`, in the order sections appear.
    static let categories: [GlobalSearchScope] = allCases.filter { $0 != .all }
}
