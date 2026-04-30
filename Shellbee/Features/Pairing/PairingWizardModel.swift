import Foundation

@Observable
final class PairingWizardModel {
    enum Step: Int, CaseIterable, Identifiable {
        case permitJoin, discovery, actions
        var id: Int { rawValue }

        var title: String {
            switch self {
            case .permitJoin: "Open Network"
            case .discovery:  "Devices"
            case .actions:    "Set Up"
            }
        }
    }

    var step: Step = .permitJoin

    /// Stamped when the wizard opens. Drives the "is this device part of
    /// THIS pairing session?" filter — anything whose first-seen timestamp
    /// predates this is from a previous session and not in scope.
    let sessionStart: Date = .now

    /// Allow a small grace window so a device that joined seconds before the
    /// user opened the wizard still shows up. Z2M's `device_joined` lands a
    /// beat before the user's tap on most networks.
    private static let graceWindow: TimeInterval = 30

    func sessionDevices(in store: AppStore) -> [Device] {
        let cutoff = sessionStart.addingTimeInterval(-Self.graceWindow)
        return store.devices
            .filter { $0.type != .coordinator }
            .filter { device in
                guard let firstSeen = store.deviceFirstSeen[device.ieeeAddress] else { return false }
                return firstSeen >= cutoff
            }
            .sorted { lhs, rhs in
                let l = store.deviceFirstSeen[lhs.ieeeAddress] ?? .distantPast
                let r = store.deviceFirstSeen[rhs.ieeeAddress] ?? .distantPast
                return l < r
            }
    }

    func interviewStatus(for device: Device) -> InterviewStatus {
        if device.interviewing { return .running }
        if device.interviewCompleted { return .completed }
        return .pending
    }

    enum InterviewStatus {
        case pending, running, completed

        var label: String {
            switch self {
            case .pending:   "Waiting"
            case .running:   "Interviewing"
            case .completed: "Ready"
            }
        }

        var systemImage: String {
            switch self {
            case .pending:   "hourglass"
            case .running:   "arrow.trianglehead.2.clockwise"
            case .completed: "checkmark.circle.fill"
            }
        }
    }
}
