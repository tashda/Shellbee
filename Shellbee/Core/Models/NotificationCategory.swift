import Foundation

enum NotificationCategory: String, CaseIterable, Codable, Hashable, Sendable {
    // Operations
    case bindSuccess
    case bindFailure
    case unbind
    case groupAdd
    case groupRemove
    case reportingConfigure
    case publishFailure
    case requestFailure
    case operationFailed
    case genericError

    // Interview
    case interviewStarted
    case interviewSuccessful
    case interviewFailed

    // Device lifecycle
    case deviceLeft

    // OTA
    case otaUpdateInstalled
    case otaNoUpdate
    case otaBulkSummary

    var displayName: String {
        switch self {
        case .bindSuccess: return "Bind Successful"
        case .bindFailure: return "Bind Failed"
        case .unbind: return "Unbound"
        case .groupAdd: return "Added to Group"
        case .groupRemove: return "Removed from Group"
        case .reportingConfigure: return "Reporting Configured"
        case .publishFailure: return "Command Failed"
        case .requestFailure: return "Request Failed"
        case .operationFailed: return "Operation Failed"
        case .genericError: return "Error"
        case .interviewStarted: return "Interviewing Device"
        case .interviewSuccessful: return "Interview Successful"
        case .interviewFailed: return "Interview Failed"
        case .deviceLeft: return "Device Left Network"
        case .otaUpdateInstalled: return "Update Installed"
        case .otaNoUpdate: return "No Update Available"
        case .otaBulkSummary: return "Bulk Check/Update Summary"
        }
    }

    enum Section: String, CaseIterable {
        case operations
        case interview
        case lifecycle
        case ota

        var title: String {
            switch self {
            case .operations: return "Operations"
            case .interview: return "Interview"
            case .lifecycle: return "Device Lifecycle"
            case .ota: return "Firmware (OTA)"
            }
        }
    }

    var section: Section {
        switch self {
        case .bindSuccess, .bindFailure, .unbind, .groupAdd, .groupRemove,
             .reportingConfigure, .publishFailure, .requestFailure,
             .operationFailed, .genericError:
            return .operations
        case .interviewStarted, .interviewSuccessful, .interviewFailed:
            return .interview
        case .deviceLeft:
            return .lifecycle
        case .otaUpdateInstalled, .otaNoUpdate, .otaBulkSummary:
            return .ota
        }
    }

    // Minimum Z2M log level at which this category is enabled by default.
    // Examples: "error" → only categories whose minimum is "error" are on.
    // "debug" turns on everything marked "debug" or lower-severity requirement.
    // otaNoUpdate is excluded from all defaults (off unless user opts in) —
    // the device list shows a transient chip for it instead.
    var defaultMinimumLogLevel: DefaultLevel {
        switch self {
        // Always on — these are critical errors
        case .operationFailed, .publishFailure, .requestFailure,
             .bindFailure, .interviewFailed, .genericError:
            return .error

        // Warning level — user should usually know
        case .deviceLeft:
            return .warning

        // Info — useful signals of completed work
        case .bindSuccess, .unbind, .groupAdd, .groupRemove,
             .reportingConfigure, .otaUpdateInstalled, .interviewSuccessful,
             .otaBulkSummary:
            return .info

        // Debug — chatty progress signals
        case .interviewStarted:
            return .debug

        // Opt-in only — user explicitly requested this is off by default
        case .otaNoUpdate:
            return .optIn
        }
    }

    enum DefaultLevel: Int, Comparable {
        case error = 0
        case warning = 1
        case info = 2
        case debug = 3
        case optIn = 99

        static func < (lhs: DefaultLevel, rhs: DefaultLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        init?(z2mLogLevel raw: String) {
            switch raw.lowercased() {
            case "error": self = .error
            case "warning", "warn": self = .warning
            case "info": self = .info
            case "debug": self = .debug
            default: return nil
            }
        }
    }
}
