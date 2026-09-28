import SwiftUI

/// Candidate designs for an activity's Lock Screen card and expanded island.
/// All of them use only what a Live Activity can render: system timers and
/// progress, numeric content transitions and symbol effects.
enum LiveActivityStyle: String, CaseIterable, Identifiable {
    /// Icon, title, large countdown, hairline progress.
    case classic
    /// A thick capsule track under the title, like a journey from A to B.
    case track
    /// A large rolling countdown with its end time, like a parking meter.
    case hero
    /// A progress ring around the icon.
    case ring
    /// Three columns: bridge, countdown, joined count.
    case scoreboard
    /// One line per item with its own bar, like a download list.
    case queue
    /// One big centred value under the icon, like a stopwatch.
    case spotlight

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: return "Classic"
        case .track: return "Track"
        case .hero: return "Hero timer"
        case .ring: return "Ring"
        case .scoreboard: return "Scoreboard"
        case .queue: return "Queue"
        case .spotlight: return "Spotlight"
        }
    }
}

extension LiveActivityLayout {
    /// The same content in another style, for comparing designs.
    func styled(_ style: LiveActivityStyle) -> LiveActivityLayout {
        var copy = self
        copy.style = style
        return copy
    }
}

/// A supporting number shown beside the main value, such as devices joined.
struct LiveActivityMetric {
    let value: String
    let label: String
}

/// Set by the Developer stage: in the app, system timer progress views
/// render as spinners, so rings are drawn by hand there instead.
private struct LiveActivityStagePreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isLiveActivityStagePreview: Bool {
        get { self[LiveActivityStagePreviewKey.self] }
        set { self[LiveActivityStagePreviewKey.self] = newValue }
    }
}
