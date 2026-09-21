import SwiftUI

extension LiveActivityLayout {
    static func permitJoin(
        attributes: PermitJoinActivityAttributes,
        state: PermitJoinActivityAttributes.ContentState,
        isStale: Bool
    ) -> Self {
        // The app is usually suspended when the window runs out, so it can't
        // end the activity itself. The stale date makes the system re-render
        // here instead, turning a frozen 0:00 into a finished state until the
        // app next runs and ends it.
        if isStale || state.endsAt <= .now {
            return Self(
                symbol: "shellbee.permitjoin",
                tint: LiveActivityPalette.neutral,
                eyebrow: attributes.bridgeDisplayName,
                title: "Network is closed",
                subtitle: joinedText(state.joinedCount, closed: true),
                value: .symbol("checkmark.circle.fill"),
                metric: LiveActivityMetric(value: "\(state.joinedCount)", label: "Joined"),
                style: .permitJoinDefault
            )
        }
        let window = state.startedAt...max(state.startedAt, state.endsAt)
        let headline = openHeadline(state)
        return Self(
            symbol: "shellbee.permitjoin",
            tint: LiveActivityPalette.pairing,
            eyebrow: attributes.bridgeDisplayName,
            title: headline.title,
            titleTint: headline.tint,
            subtitle: headline.subtitle,
            value: .countdown(window),
            gauge: .countdown(window),
            compactValue: state.recentlyPaired == nil ? nil : .text("+1"),
            compactTint: state.recentlyPaired == nil ? nil : LiveActivityPalette.success,
            isBusy: !state.interviewing.isEmpty,
            metric: LiveActivityMetric(value: "\(state.joinedCount)", label: "Joined"),
            style: .permitJoinDefault
        )
    }

    /// The latest event outranks the pairing window itself: a device that
    /// just paired, then a failure, then interviews in progress, then "open"
    /// with the joined count. The bee and the countdown already say the
    /// network is open.
    static func openHeadline(_ state: PermitJoinActivityAttributes.ContentState) -> (title: String, subtitle: String, tint: Color?) {
        if let paired = state.recentlyPaired {
            return ("Paired", paired, LiveActivityPalette.success)
        }
        if let failed = state.interviewFailure {
            return ("Interview failed", failed, LiveActivityPalette.failure)
        }
        switch state.interviewing.count {
        case 0: return ("Network is open", joinedText(state.joinedCount), nil)
        case 1: return ("Interviewing", state.interviewing[0], nil)
        default: return ("Interviewing", "\(state.interviewing.count) devices", nil)
        }
    }

    static func joinedText(_ count: Int, closed: Bool = false) -> String {
        switch count {
        case 0: return closed ? "No devices joined" : "Waiting for devices"
        case 1: return "1 device joined"
        default: return "\(count) devices joined"
        }
    }
}

extension LiveActivityStyle {
    /// The style the Permit Join widget renders with.
    static let permitJoinDefault: LiveActivityStyle = .hero
}
