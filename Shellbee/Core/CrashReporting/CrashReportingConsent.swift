import Foundation
import Observation

@Observable
final class CrashReportingConsent {
    static let shared = CrashReportingConsent()

    private enum Keys {
        static let alwaysShare = "crashReporting.alwaysShare"
        static let hasAnswered = "crashReporting.hasAnswered"
    }

    var alwaysShare: Bool {
        didSet {
            UserDefaults.standard.set(alwaysShare, forKey: Keys.alwaysShare)
            UserDefaults.standard.set(true, forKey: Keys.hasAnswered)
        }
    }

    var hasAnswered: Bool {
        UserDefaults.standard.bool(forKey: Keys.hasAnswered)
    }

    private init() {
        alwaysShare = UserDefaults.standard.bool(forKey: Keys.alwaysShare)
    }
}
