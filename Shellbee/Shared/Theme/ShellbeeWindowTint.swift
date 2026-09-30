import SwiftUI
import UIKit

/// Gives the window the theme accent as its UIKit `tintColor`. SwiftUI's
/// `.tint` reaches SwiftUI content only; alerts, confirmation dialogs,
/// menus, context menus, list selection marks and search bars draw with the
/// window's tint, which otherwise stays system blue. Standard clears it.
private struct ShellbeeWindowTint: UIViewRepresentable {
    let accent: Color?

    func makeUIView(context: Context) -> TintProbeView {
        TintProbeView()
    }

    func updateUIView(_ view: TintProbeView, context: Context) {
        view.accent = accent.map { UIColor($0) }
    }

    final class TintProbeView: UIView {
        nonisolated deinit {}

        var accent: UIColor? {
            didSet { applyTint() }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyTint()
        }

        private func applyTint() {
            window?.tintColor = accent
        }
    }
}

extension View {
    /// Apply once per window root, below the theme environment.
    func shellbeeWindowTint(_ theme: ShellbeeTheme) -> some View {
        background(ShellbeeWindowTint(accent: theme.palette?.accent).allowsHitTesting(false))
    }
}
