import ActivityKit
import Foundation

/// Plays a scripted pairing session on a demo Permit Join activity, so every
/// Dynamic Island and Lock Screen state can be seen on a real device without
/// a bridge. Leave the app right after starting it: the whole script fits in
/// the background time iOS grants while an activity is on screen.
@MainActor
enum PermitJoinActivityPreview {
    private static var script: Task<Void, Never>?

    static func run() {
        script?.cancel()
        script = Task { await play() }
    }

    private static func play() async {
        let start = Date.now
        let end = start.addingTimeInterval(DesignTokens.Duration.liveActivityPreviewWindow)
        var state = PermitJoinActivityAttributes.ContentState(joinedCount: 0, startedAt: start, endsAt: end, targetName: nil)
        let attributes = PermitJoinActivityAttributes(identifier: "permit-join-preview", bridgeDisplayName: "")
        guard let activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: end)
        ) else { return }

        let steps: [(delay: Double, alert: AlertConfiguration?, change: (inout PermitJoinActivityAttributes.ContentState) -> Void)] = [
            (4, nil, { $0.interviewing = ["Hallway Sensor"] }),
            (6, AlertConfiguration(title: "Paired", body: "Hallway Sensor", sound: .default), {
                $0 = .init(joinedCount: 1, startedAt: $0.startedAt, endsAt: $0.endsAt, targetName: nil, recentlyPaired: "Hallway Sensor")
            }),
            (4, nil, { $0.recentlyPaired = nil }),
            (2, nil, { $0.interviewing = ["Kitchen Plug"] }),
            (5, AlertConfiguration(title: "Interview failed", body: "Kitchen Plug", sound: .default), {
                $0.interviewing = []
                $0.interviewFailure = "Kitchen Plug"
            })
        ]
        for step in steps {
            try? await Task.sleep(for: .seconds(step.delay))
            guard !Task.isCancelled else { break }
            step.change(&state)
            await activity.update(ActivityContent(state: state, staleDate: end), alertConfiguration: step.alert)
        }
        try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityPreviewLinger))
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
