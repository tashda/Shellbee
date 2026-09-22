import SwiftUI
import UIKit

/// A symbol reference that may resolve to SF Symbols or to one of the app's
/// own symbol sets in `Assets.xcassets/Custom Icons`.
///
/// The two are drawn by different initializers — `Image(systemName:)` versus
/// `Image(_:)` — and a custom name passed to the former silently renders
/// nothing. Carrying the origin alongside the name means call sites can't get
/// that wrong, and a screen can move between a stock and a custom icon without
/// touching its layout.
struct ShellbeeSymbol: Hashable, Sendable {
    let name: String
    let isCustom: Bool

    /// An SF Symbol, named exactly as SF Symbols reports it.
    static func system(_ name: String) -> ShellbeeSymbol {
        ShellbeeSymbol(name: name, isCustom: false)
    }

    /// One of the app's own symbols. Pass the bare name (`"home"`); the
    /// `shellbee.` prefix every custom symbol set carries is added here, so
    /// the catalog can grow without a custom icon ever shadowing — or being
    /// shadowed by — a current or future SF Symbol of the same name.
    static func custom(_ name: String) -> ShellbeeSymbol {
        ShellbeeSymbol(name: Self.customPrefix + name, isCustom: true)
    }

    static let customPrefix = "shellbee."

    /// Permit Join everywhere it appears: the Home toolbar, the pairing
    /// sheets, and the Live Activity (which carries its own copy of the set).
    static let permitJoin = custom("permitjoin")

    var image: Image {
        isCustom ? Image(name) : Image(systemName: name)
    }

    /// `image`'s UIKit equivalent, for call sites that need a `UIImage`
    /// (toolbar/menu items) — `Image(_:)`'s asset-catalog initializer has no
    /// UIKit counterpart that takes a bare name, so this goes through
    /// `UIImage(named:)` instead.
    var uiImage: UIImage? {
        isCustom ? UIImage(named: name) : UIImage(systemName: name)
    }

    /// The raw form a `ShellbeeSymbol` round-trips through when only a
    /// single `String` can be persisted — a custom symbol's name already
    /// carries its `shellbee.` prefix, so no separate flag is needed to tell
    /// the two apart on the way back in.
    var raw: String { name }

    /// Reverses `raw` — a plain SF Symbol name resolves to `.system`, a name
    /// already carrying the `shellbee.` prefix resolves to `.custom`.
    static func resolved(from raw: String) -> ShellbeeSymbol {
        raw.hasPrefix(customPrefix) ? .custom(String(raw.dropFirst(customPrefix.count))) : .system(raw)
    }
}

extension Label where Title == Text, Icon == Image {
    /// The `Label(_:systemImage:)` equivalent that also accepts custom
    /// symbols. Custom symbol sets are templates like any SF Symbol, so the
    /// result takes font, `imageScale`, weight, and foreground style the same
    /// way — nothing downstream has to special-case them.
    init(_ title: String, symbol: ShellbeeSymbol) {
        self.init { Text(title) } icon: { symbol.image }
    }
}
