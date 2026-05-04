import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var isInitializing = true
    @State private var pendingCrash: PendingCrash?
    @AppStorage(OnboardingStep.completedKey) private var onboardingCompleted: Bool = false
    @State private var showOnboarding = false

    /// Phase 2 multi-bridge: the most-attention-needing state across every
    /// connected session. `lost` always wins so the banner / alert surface
    /// it; otherwise we pick connecting / reconnecting / connected by
    /// priority. When zero sessions exist we report `.idle`.
    private var aggregateConnectionState: ConnectionSessionController.State {
        let sessions = environment.registry.orderedSessions
        if let lost = sessions.first(where: { if case .lost = $0.connectionState { return true }; return false }) {
            return lost.connectionState
        }
        if let failed = sessions.first(where: { if case .failed = $0.connectionState { return true }; return false }) {
            return failed.connectionState
        }
        if sessions.contains(where: { if case .reconnecting = $0.connectionState { return true }; return false }) {
            return .reconnecting(attempt: 0)
        }
        if sessions.contains(where: { $0.connectionState == .connecting }) {
            return .connecting
        }
        if sessions.contains(where: { $0.connectionState == .connected }) {
            return .connected
        }
        return .idle
    }

    /// First session currently in `.lost`. The banner / alert show its
    /// state and target retry/forget at this specific bridge.
    private var lostSession: BridgeSession? {
        environment.registry.orderedSessions.first { session in
            if case .lost = session.connectionState { return true }
            return false
        }
    }

    var body: some View {
        ZStack {
            if isInitializing {
                SplashScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
            } else if environment.hasAnyBridgeBeenConnected {
                mainInterface
            } else {
                setupInterface
            }
        }
        .animation(.spring(duration: DesignTokens.Duration.slowAnimation), value: isInitializing)
        .sheet(item: $pendingCrash) { crash in
            PendingCrashSheet(
                crash: crash,
                onShare: { SentryService.shared.approveAndSendPending() },
                onAlwaysShare: { SentryService.shared.enableAlwaysShareAndSendPending() },
                onDiscard: { SentryService.shared.discardPending() }
            )
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
                .environment(environment)
        }
        .onChange(of: isInitializing) { _, stillInitializing in
            // First-launch only. Defer until splash dismisses so the cover
            // doesn't fight the splash transition.
            guard !stillInitializing,
                  !onboardingCompleted,
                  !environment.hasSavedBridges
            else { return }
            showOnboarding = true
        }
        .task {
            // Start the environment (auto-connect if config exists)
            await environment.start()

            if environment.hasSavedBridges {
                let startTime = Date()
                while Date().timeIntervalSince(startTime) < 5.0 {
                    if environment.hasAnyBridgeBeenConnected { break }
                    if case .failed = aggregateConnectionState { break }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            withAnimation {
                isInitializing = false
            }

            if let crash = PendingCrashStore.load() {
                pendingCrash = crash
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Phase 2 multi-bridge: on foreground, retry every session that's
            // in a recoverable bad state. `hasBeenConnected` per-session
            // means we only retry bridges the user successfully connected to
            // before — never undo an explicit disconnect.
            guard phase == .active else { return }
            for session in environment.registry.orderedSessions {
                guard session.controller.hasBeenConnected else { continue }
                switch session.connectionState {
                case .lost, .failed, .idle:
                    environment.retryFromLost(bridgeID: session.bridgeID)
                case .connecting, .connected, .reconnecting:
                    continue
                }
            }
        }
    }

    // MARK: - Main interface (shown after first successful connection)

    private var mainInterface: some View {
        MainTabView()
            .overlay(alignment: .top) { connectionBanner }
            .alert("Connection Lost", isPresented: lostBinding) {
                Button("Try Again") {
                    if let id = lostSession?.bridgeID {
                        environment.retryFromLost(bridgeID: id)
                    }
                }
                Button("Change Server", role: .destructive) {
                    if let id = lostSession?.bridgeID {
                        Task { await environment.forgetServer(bridgeID: id) }
                    }
                }
            } message: {
                if case .lost(let msg) = lostSession?.connectionState {
                    Text(msg)
                }
            }
    }

    // MARK: - Setup interface (before first successful connection)

    private var setupInterface: some View {
        ConnectionSetupView(environment: environment)
    }

    // MARK: - Reconnect banner (shown over MainTabView)

    @ViewBuilder
    private var connectionBanner: some View {
        switch aggregateConnectionState {
        case .lost(let msg):
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "wifi.slash")
                Text(msg)
                    .font(.footnote)
                    .lineLimit(2)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, DesignTokens.Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
        default:
            EmptyView()
        }
    }

    private var lostBinding: Binding<Bool> {
        Binding(
            get: { lostSession != nil },
            set: { _ in }
        )
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
