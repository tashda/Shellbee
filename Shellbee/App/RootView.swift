import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var isInitializing = true
    @State private var pendingCrash: PendingCrash?

    var body: some View {
        ZStack {
            if isInitializing {
                SplashScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
            } else if environment.hasBeenConnected {
                mainInterface
            } else {
                setupInterface
            }
        }
        .animation(.spring(duration: 0.6), value: isInitializing)
        .sheet(item: $pendingCrash) { crash in
            PendingCrashSheet(
                crash: crash,
                onShare: { SentryService.shared.approveAndSendPending() },
                onAlwaysShare: { SentryService.shared.enableAlwaysShareAndSendPending() },
                onDiscard: { SentryService.shared.discardPending() }
            )
        }
        .task {
            // Start the environment (auto-connect if config exists)
            await environment.start()
            
            if environment.connectionConfig != nil {
                let startTime = Date()
                while Date().timeIntervalSince(startTime) < 5.0 {
                    if environment.hasBeenConnected { break }
                    if case .failed = environment.connectionState { break }
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
            // Reconnect only if the user had an established session that
            // dropped while backgrounded. `hasBeenConnected` is cleared by
            // explicit disconnect / forget-server, so we don't undo a
            // user-initiated disconnect on the next foreground.
            guard phase == .active,
                  environment.hasBeenConnected,
                  environment.connectionConfig != nil
            else { return }
            switch environment.connectionState {
            case .lost, .failed, .idle:
                environment.retryFromLost()
            case .connecting, .connected, .reconnecting:
                break
            }
        }
    }

    // MARK: - Main interface (shown after first successful connection)

    private var mainInterface: some View {
        MainTabView()
            .overlay(alignment: .top) { connectionBanner }
            .alert("Connection Lost", isPresented: lostBinding) {
                Button("Try Again") { environment.retryFromLost() }
                Button("Change Server", role: .destructive) { Task { await environment.forgetServer() } }
            } message: {
                if case .lost(let msg) = environment.connectionState {
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
        switch environment.connectionState {
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
            get: {
                if case .lost = environment.connectionState { return true }
                return false
            },
            set: { _ in }
        )
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
