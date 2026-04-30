import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, connect, test, done
    var id: Int { rawValue }

    static let storedIndexKey = "onboardingPageIndex"
    static let completedKey = "onboardingCompleted"
}
