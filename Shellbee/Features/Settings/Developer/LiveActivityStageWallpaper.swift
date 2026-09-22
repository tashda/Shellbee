import SwiftUI

/// Wallpapers for the Live Activity stage. Activities sit on translucent
/// glass, so they have to be judged against light, dark and colourful
/// backgrounds, not just black.
@available(iOS 26.0, *)
enum LiveActivityStageWallpaper: String, CaseIterable, Identifiable {
    case sand, night, bloom

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sand: return "Sand"
        case .night: return "Night"
        case .bloom: return "Bloom"
        }
    }

    var view: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: colors
        )
    }

    private var colors: [Color] {
        switch self {
        case .sand:
            return [
                Color(red: 0.55, green: 0.42, blue: 0.30), Color(red: 0.80, green: 0.72, blue: 0.62), Color(red: 0.92, green: 0.88, blue: 0.82),
                Color(red: 0.36, green: 0.27, blue: 0.20), Color(red: 0.70, green: 0.60, blue: 0.50), Color(red: 0.85, green: 0.80, blue: 0.74),
                Color(red: 0.20, green: 0.18, blue: 0.22), Color(red: 0.40, green: 0.36, blue: 0.40), Color(red: 0.62, green: 0.58, blue: 0.56)
            ]
        case .night:
            return [
                Color(red: 0.05, green: 0.07, blue: 0.16), Color(red: 0.10, green: 0.14, blue: 0.30), Color(red: 0.04, green: 0.06, blue: 0.14),
                Color(red: 0.08, green: 0.16, blue: 0.32), Color(red: 0.18, green: 0.26, blue: 0.48), Color(red: 0.06, green: 0.10, blue: 0.22),
                Color(red: 0.02, green: 0.03, blue: 0.08), Color(red: 0.08, green: 0.10, blue: 0.20), Color(red: 0.03, green: 0.04, blue: 0.10)
            ]
        case .bloom:
            return [
                Color(red: 0.78, green: 0.62, blue: 0.78), Color(red: 0.86, green: 0.74, blue: 0.82), Color(red: 0.70, green: 0.55, blue: 0.78),
                Color(red: 0.55, green: 0.45, blue: 0.78), Color(red: 0.80, green: 0.66, blue: 0.84), Color(red: 0.50, green: 0.40, blue: 0.75),
                Color(red: 0.30, green: 0.28, blue: 0.62), Color(red: 0.38, green: 0.34, blue: 0.70), Color(red: 0.26, green: 0.24, blue: 0.58)
            ]
        }
    }
}
