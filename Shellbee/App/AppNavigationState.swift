import Foundation

enum AppTab: Hashable, CaseIterable {
    case home, devices, groups, settings
}

enum DeviceQuickFilter: Hashable {
    case all
    case online
    case offline
    case batteryLow
    case weakSignal
    case interviewing
    case unsupported
    case updatesAvailable
    case router
    case endDevice
}
