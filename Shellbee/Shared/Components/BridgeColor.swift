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

/// User preference for whether the leading-edge bridge color tint is
/// rendered on rows. Persisted via `@AppStorage("bridgeGradientMode")` so
/// the picker in Settings → Application → General is the single source of
/// truth.
enum BridgeGradientMode: String, CaseIterable, Identifiable {
    /// Always paint the gradient, even when only one bridge is connected.
    case always
    /// Default. Paint only when 2+ bridges are connected — single-bridge
    /// users see no extra chrome.
    case auto
    /// Never paint the gradient.
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

/// A small colored dot used in row corners to indicate a device/log/group's
/// source bridge. Auto-hides when only one bridge is connected (single-bridge
/// users see no clutter). Pair with `.help(bridgeName)` for accessibility.
struct BridgeColorDot: View {
    let bridgeID: UUID
    let bridgeName: String
    var size: CGFloat = 8

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        if environment.registry.sessions.values.filter(\.isConnected).count >= 2 {
            Circle()
                .fill(BridgeColor.color(for: bridgeID))
                .frame(width: size, height: size)
                .accessibilityLabel("Bridge: \(bridgeName)")
                .help(bridgeName)
        }
    }
}

/// A thin solid color line on the cell's leading edge that runs the full
/// height of the row. Used uniformly across Devices, Groups, and Logs as
/// the multi-bridge attribution signal — apply to any row with
/// `.listRowBackground(BridgeRowLeadingBar(bridgeID: bridgeID))`.
///
/// The standard cell separator hairline draws between adjacent rows on top
/// of the background, so consecutive rows from the same bridge read as a
/// continuous color column with hairline breaks at row boundaries — no
/// per-row vertical padding needed.
///
/// Visibility honors the user's `Bridge Indicator` setting (Always /
/// Automatic / Off). Color updates re-render via `@AppStorage` observation
/// of `bridgeColorRevision`, so saving a new color in the editor repaints
/// every visible AND off-screen row immediately.
struct BridgeRowLeadingBar: View {
    let bridgeID: UUID?

    @Environment(AppEnvironment.self) private var environment
    @AppStorage(BridgeColorObserver.revisionKey) private var colorRevision: Int = 0
    @AppStorage(BridgeGradientMode.storageKey) private var indicatorModeRaw: String = BridgeGradientMode.default.rawValue

    private var indicatorMode: BridgeGradientMode {
        BridgeGradientMode(rawValue: indicatorModeRaw) ?? BridgeGradientMode.default
    }

    private var isVisible: Bool {
        guard bridgeID != nil else { return false }
        switch indicatorMode {
        case .always: return true
        case .off:    return false
        case .auto:   return environment.registry.sessions.values.filter(\.isConnected).count >= 2
        }
    }

    /// Width of the leading bar. 3pt reads as a deliberate accent without
    /// stealing horizontal space from the row content.
    private static let barWidth: CGFloat = 3

    var body: some View {
        // Read colorRevision so SwiftUI tracks it as a dependency.
        let _ = colorRevision

        // Color.clear so the row inherits the list's underlying backdrop —
        // `.secondarySystemGroupedBackground` is the inset-grouped card
        // tint and renders as a visible "card" against a `.plain` list in
        // dark mode (lighter grey on darker grey). The leading bar still
        // paints on top of the clear background as a discrete accent.
        Color.clear
            .overlay(alignment: .leading) {
                if isVisible, let bridgeID {
                    Rectangle()
                        .fill(BridgeColor.color(for: bridgeID))
                        .frame(width: Self.barWidth)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// Backward-compat alias for the old gradient-styled name. New call sites
/// should use `BridgeRowLeadingBar` directly.
typealias BridgeRowGradientBackground = BridgeRowLeadingBar

/// A 3pt-wide tinted vertical bar flush against the row's leading edge.
struct BridgeColorBar: View {
    let bridgeID: UUID?
    let bridgeName: String

    @Environment(AppEnvironment.self) private var environment

    private var isVisible: Bool {
        guard bridgeID != nil else { return false }
        return environment.registry.sessions.values.filter(\.isConnected).count >= 2
    }

    var body: some View {
        if isVisible, let bridgeID {
            Capsule(style: .continuous)
                .fill(BridgeColor.color(for: bridgeID))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 6)
                .accessibilityLabel("Bridge: \(bridgeName)")
        } else {
            Color.clear.frame(width: 0)
        }
    }
}
