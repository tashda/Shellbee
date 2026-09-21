import SwiftUI

/// An activity the gallery can show, with one sample per state worth
/// reviewing. Samples are built from the same layout functions the widget
/// uses, so what's shown here is what the system renders.
enum LiveActivityGalleryKind: String, CaseIterable, Identifiable {
    case permitJoin
    case otaUpdate
    case touchlinkScan
    case touchlinkIdentify

    var id: String { rawValue }

    var name: String {
        switch self {
        case .permitJoin: return "Permit Join"
        case .otaUpdate: return "OTA Update"
        case .touchlinkScan: return "Touchlink Scan"
        case .touchlinkIdentify: return "Touchlink Identify"
        }
    }

    var symbol: ShellbeeSymbol {
        switch self {
        case .permitJoin: return .permitJoin
        case .otaUpdate: return .system("arrow.down.circle")
        case .touchlinkScan: return .system("dot.radiowaves.left.and.right")
        case .touchlinkIdentify: return .system("lightbulb.max")
        }
    }

    /// The style the widget currently ships with.
    var defaultStyle: LiveActivityStyle {
        switch self {
        case .permitJoin: return .permitJoinDefault
        case .otaUpdate: return .otaUpdateDefault
        case .touchlinkScan: return .touchlinkScanDefault
        case .touchlinkIdentify: return .touchlinkIdentifyDefault
        }
    }

    /// The designs worth comparing for this activity.
    var styles: [LiveActivityStyle] {
        switch self {
        case .permitJoin: return [.classic, .track, .hero, .ring, .scoreboard]
        case .otaUpdate: return [.hero, .queue, .track, .ring, .spotlight, .scoreboard, .classic]
        case .touchlinkScan: return [.ring, .spotlight, .scoreboard, .hero, .track, .classic]
        case .touchlinkIdentify: return [.spotlight, .ring, .hero, .track, .classic]
        }
    }

    /// Countdowns start at `anchor`, so re-anchoring restarts every timer.
    func samples(anchor: Date) -> [LiveActivityGallerySample] {
        switch self {
        case .permitJoin: return PermitJoinGallerySamples.all(anchor: anchor)
        case .otaUpdate: return OTAUpdateGallerySamples.all(anchor: anchor)
        case .touchlinkScan: return TouchlinkGallerySamples.scan(anchor: anchor)
        case .touchlinkIdentify: return TouchlinkGallerySamples.identify(anchor: anchor)
        }
    }
}

struct LiveActivityGallerySample: Identifiable {
    let name: String
    let layout: LiveActivityLayout
    var id: String { name }
}

private enum PermitJoinGallerySamples {
    static func all(anchor: Date) -> [LiveActivityGallerySample] {
        let end = anchor.addingTimeInterval(DesignTokens.Duration.liveActivityGalleryWindow)
        let single = PermitJoinActivityAttributes(identifier: "gallery", bridgeDisplayName: "")
        let multiBridge = PermitJoinActivityAttributes(identifier: "gallery", bridgeDisplayName: "Upstairs Bridge")

        func state(joined: Int = 0, interviewing: [String] = [], failure: String? = nil, paired: String? = nil, ended: Bool = false) -> PermitJoinActivityAttributes.ContentState {
            .init(
                joinedCount: joined,
                startedAt: anchor,
                endsAt: ended ? anchor : end,
                targetName: nil,
                interviewing: interviewing,
                interviewFailure: failure,
                recentlyPaired: paired
            )
        }

        func sample(_ name: String, _ state: PermitJoinActivityAttributes.ContentState, _ attributes: PermitJoinActivityAttributes = single) -> LiveActivityGallerySample {
            LiveActivityGallerySample(name: name, layout: .permitJoin(attributes: attributes, state: state, isStale: false))
        }

        return [
            sample("Waiting", state()),
            sample("Interviewing", state(interviewing: ["Hallway Motion Sensor"])),
            sample("Interviewing several", state(joined: 1, interviewing: ["Hallway Motion Sensor", "Kitchen Plug"])),
            sample("Paired", state(joined: 1, paired: "Hallway Motion Sensor")),
            sample("Interview failed", state(joined: 1, failure: "Kitchen Plug")),
            sample("Devices joined", state(joined: 3)),
            sample("Several bridges", state(joined: 3), multiBridge),
            sample("Long device name", state(interviewing: ["Living Room Ceiling Light Left Corner"]), multiBridge),
            sample("Closed", state(joined: 3, ended: true))
        ]
    }
}
