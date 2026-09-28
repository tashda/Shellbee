import SwiftUI

/// Bridge color wrapper for app-target views.
enum BridgeColor {
    static let palette: [Color] = DesignTokens.Bridge.palette

    static func color(for bridgeID: UUID) -> Color {
        DesignTokens.Bridge.color(for: bridgeID)
    }

    static func autoIndex(for bridgeID: UUID) -> Int {
        DesignTokens.Bridge.autoIndex(for: bridgeID)
    }
}

/// Color-override change broadcast. Backs the legacy
/// `BridgeColorObserver.shared.bump()` API. Two channels:
///
/// 1. `UserDefaults.standard.set(value, forKey: bridgeColorRevisionKey)` —
///    `@AppStorage("bridgeColorRevision")` observers re-render reliably,
///    including off-screen List cells that the SwiftUI/UICollectionView
///    bridge would otherwise leave stale until they scroll into view.
/// 2. `Notification.Name.bridgeColorChanged` — for any non-SwiftUI listener
///    that wants to react to color changes.
///
/// The connection editor calls `BridgeColorObserver.shared.bump()` after
/// `DesignTokens.Bridge.setCustomColor(_:for:)` to fire both.
@MainActor
final class BridgeColorObserver {
    static let shared = BridgeColorObserver()
    static let revisionKey = "bridgeColorRevision"
    private init() {}
    func bump() {
        let next = UserDefaults.standard.integer(forKey: Self.revisionKey) &+ 1
        UserDefaults.standard.set(next, forKey: Self.revisionKey)
        NotificationCenter.default.post(name: .bridgeColorChanged, object: nil)
    }
}

extension Notification.Name {
    /// Posted whenever a bridge's color override is saved.
    static let bridgeColorChanged = Notification.Name("BridgeColorChanged")
}

/// When bridge monograms show (Appearance → Bridge Indicators). The stored
/// key keeps its original name so existing choices carry over.
enum BridgeGradientMode: String, CaseIterable, Identifiable {
    /// Show monograms even with one bridge connected.
    case always
    /// Default. Show them only while two or more bridges are connected.
    case auto
    /// Never show them.
    case off

    static let storageKey = "bridgeGradientMode"
    static let `default`: BridgeGradientMode = .auto

    var id: String { rawValue }

    var label: String {
        switch self {
        case .always: return "Always"
        case .auto:   return "Automatic"
        case .off:    return "Off"
        }
    }
}
