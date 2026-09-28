import Foundation

extension AppStore {
    /// Keep the pairing activity derived from bridge state. This means a
    /// reconnect, bridge/info refresh, or explicit close all converge on the
    /// same visibility decision instead of leaving a stale activity behind.
    func syncPermitJoinLiveActivity() {
        let info = bridgeInfo
        let isOpen = info?.permitJoin == true
        // A window opened elsewhere (the Z2M frontend, another client) never
        // passes through `setPermitJoin`, so reset the count on any
        // closed-to-open transition rather than only on in-app opens.
        if isOpen, !permitJoinWasOpen {
            permitJoinJoinedCount = 0
            permitJoinInterviewing = []
            permitJoinInterviewFailure = nil
        }
        permitJoinWasOpen = isOpen
        PermitJoinLiveActivityCoordinator.shared.sync(
            bridgeID: activeBridgeID,
            bridgeDisplayName: LiveActivityBridgeLabel.name(activeBridgeName),
            isOpen: isOpen,
            endMilliseconds: info?.permitJoinEnd,
            targetName: info?.permitJoinTarget,
            joinedCount: permitJoinJoinedCount,
            interviewing: permitJoinInterviewing,
            interviewFailure: permitJoinInterviewFailure,
            recentlyPaired: permitJoinRecentlyPaired
        )
    }

    /// Called just before the app is suspended: an interview that finishes
    /// while suspended would otherwise read "Interviewing" forever, so the
    /// card falls back to the joined count, which stays true.
    func forgetUnfollowableInterviews() {
        guard !permitJoinInterviewing.isEmpty || permitJoinRecentlyPaired != nil else { return }
        permitJoinInterviewing = []
        permitJoinRecentlyPaired = nil
        syncPermitJoinLiveActivity()
    }

    /// Interviews are shown on the pairing card. One that started inside the
    /// window is followed to the end even if the window closes first.
    func trackPermitJoinInterview(name: String, status: String) {
        let isTracked = permitJoinInterviewing.contains(name)
        guard bridgeInfo?.permitJoin == true || isTracked else { return }
        switch status {
        case "started":
            if !isTracked { permitJoinInterviewing.append(name) }
            permitJoinInterviewFailure = nil
        case "successful":
            permitJoinInterviewing.removeAll { $0 == name }
            celebratePairing(name)
        case "failed":
            permitJoinInterviewing.removeAll { $0 == name }
            permitJoinInterviewFailure = name
        default:
            return
        }
        syncPermitJoinLiveActivity()
    }

    /// Shows "Paired" and a "+1" on the card for a moment, then settles back
    /// to the running count.
    private func celebratePairing(_ name: String) {
        permitJoinRecentlyPaired = name
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.liveActivityPairedMoment))
            guard let self, self.permitJoinRecentlyPaired == name else { return }
            self.permitJoinRecentlyPaired = nil
            self.syncPermitJoinLiveActivity()
        }
    }
}
