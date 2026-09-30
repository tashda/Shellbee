import SwiftUI

/// Which bridge something belongs to: a small rounded square in the bridge's
/// colour holding its initial. Sits beside metadata people already read (a
/// vendor, an event's time, a device's chips) instead of marking the row's
/// edge. Shown per the Bridge Indicators setting, so single-bridge users see
/// nothing by default.
struct BridgeMonogram: View {
    let bridgeID: UUID
    /// Looked up from the bridge's session when not given.
    var bridgeName: String? = nil
    var size: CGFloat = DesignTokens.Size.bridgeMonogram

    @Environment(AppEnvironment.self) private var environment
    @AppStorage(BridgeColorObserver.revisionKey) private var colorRevision: Int = 0
    @AppStorage(BridgeGradientMode.storageKey) private var indicatorModeRaw = BridgeGradientMode.default.rawValue

    var body: some View {
        // Read colorRevision so a saved colour repaints every monogram.
        let _ = colorRevision
        if BridgeGradientMode.stored(indicatorModeRaw).showsIndicators(in: environment) {
            let name = bridgeName ?? environment.registry.session(for: bridgeID)?.displayName ?? ""
            BridgeMonogramMark(initial: Self.initial(for: name),
                               color: BridgeColor.color(for: bridgeID),
                               size: size)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.accessibilityLabel(for: name))
        }
    }

    /// What VoiceOver reads for the mark. Rows that flatten their children
    /// into one label append this so the bridge isn't lost.
    static func accessibilityLabel(for name: String) -> String {
        String(localized: "Bridge: \(name)")
    }

    static func initial(for name: String) -> String {
        name.first(where: { $0.isLetter || $0.isNumber }).map { String($0).uppercased() } ?? "?"
    }
}

/// The drawn mark alone, for previews that don't have a real bridge.
struct BridgeMonogramMark: View {
    let initial: String
    let color: Color
    var size: CGFloat = DesignTokens.Size.bridgeMonogram

    var body: some View {
        RoundedRectangle(cornerRadius: size * DesignTokens.Ratio.bridgeMonogramCorner, style: .continuous)
            .fill(color)
            .overlay {
                Text(initial)
                    .font(.system(size: size * DesignTokens.Ratio.bridgeMonogramGlyph, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
    }
}

extension BridgeGradientMode {
    static func stored(_ rawValue: String) -> Self {
        Self(rawValue: rawValue) ?? .default
    }

    func showsIndicators(in environment: AppEnvironment) -> Bool {
        switch self {
        case .always: true
        case .off: false
        case .auto: environment.registry.sessions.values.filter(\.isConnected).count >= 2
        }
    }
}

#Preview {
    HStack(spacing: DesignTokens.Spacing.md) {
        BridgeMonogramMark(initial: "H", color: .orange)
        BridgeMonogramMark(initial: "L", color: .purple, size: DesignTokens.Size.bridgeMonogramLarge)
    }
    .padding()
}
