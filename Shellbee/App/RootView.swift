import SwiftUI

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isInitializing = true

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
        .task {
            // Start the environment (auto-connect if config exists)
            await environment.start()
            
            // Wait for a minimum time for the splash to be "beautiful"
            // and also wait for connection if we have a config
            let startTime = Date()
            let minimumSplashDuration: TimeInterval = 1.8
            
            if environment.connectionConfig != nil {
                // We are auto-connecting, wait for result or timeout
                while Date().timeIntervalSince(startTime) < 5.0 {
                    if environment.hasBeenConnected { break }
                    if case .failed = environment.connectionState { break }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
            
            // Ensure minimum duration
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < minimumSplashDuration {
                try? await Task.sleep(for: .seconds(minimumSplashDuration - elapsed))
            }
            
            withAnimation {
                isInitializing = false
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
        case .reconnecting(let attempt):
            HStack(spacing: DesignTokens.Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("Reconnecting… (attempt \(attempt) of \(AppEnvironment.maxReconnectAttempts))")
                    .font(.footnote)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, DesignTokens.Spacing.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
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
