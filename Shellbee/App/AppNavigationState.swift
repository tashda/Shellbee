import Foundation

enum AppTab: Hashable, CaseIterable {
    case home, devices, groups, settings
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
