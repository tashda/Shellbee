import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(OnboardingStep.completedKey) private var completed: Bool = false
    @AppStorage(OnboardingStep.storedIndexKey) private var storedIndex: Int = 0
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title(for: step))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Skip is available on the entry pages where the user
                    // hasn't committed to anything yet (welcome, test). Hidden
                    // on .connect (the user must attempt a connection) and
                    // .done (Get Started is the only sensible action).
                    if step == .welcome || step == .test {
                        // Trailing on purpose: iPadOS 26 places the window
                        // traffic-light controls in the leading nav bar
                        // area, so a leading Skip overlaps them.
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Skip") { finish() }
                        }
                    }
                }
                .onAppear {
                    if let restored = OnboardingStep(rawValue: storedIndex) {
                        step = restored
                    }
                }
                .onChange(of: step) { _, newValue in
                    storedIndex = newValue.rawValue
                }
                .onChange(of: environment.selectedScope?.connectionState) { _, newState in
                    // Phase 2 multi-bridge: onboarding connects exactly one
                    // bridge — the user's first. selectedScope tracks it.
                    guard step == .connect, let newState else { return }
                    switch newState {
                    case .connecting, .connected, .reconnecting:
                        step = .test
                    default:
                        break
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            WelcomePage(onContinue: { step = .connect })
        case .connect:
            OnboardingConnectPage()
        case .test:
            OnboardingTestPage(onContinue: { step = .done }, onRetry: { step = .connect })
        case .done:
            DonePage(onFinish: finish)
        }
    }

    private func title(for step: OnboardingStep) -> String {
        switch step {
        case .welcome: ""
        case .connect: "Connect"
        case .test:    "Testing Connection"
        case .done:    "All Set"
        }
    }

    private func finish() {
        completed = true
        storedIndex = 0
        dismiss()
    }
}

// MARK: - Welcome page

private struct WelcomePage: View {
    @Environment(\.colorScheme) private var colorScheme
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            HomeBackgroundGradient()
                .ignoresSafeArea()

            VStack {
                Spacer()
                Image(colorScheme == .dark ? "SplashAppIconDark" : "SplashAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: DesignTokens.Size.permitJoinQR, height: DesignTokens.Size.permitJoinQR)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))

                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Welcome to Shellbee")
                        .font(.largeTitle.weight(.bold))
                    Text("Let's get you connected.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, DesignTokens.Spacing.xl)
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
        }
    }
}

// MARK: - Done page

private struct DonePage: View {
    @Environment(AppEnvironment.self) private var environment
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .bounceSymbolEffectIfAvailable()
            Text("You're all set")
                .font(.largeTitle.weight(.bold))
            // Phase 2 multi-bridge: count devices on the bridge the user
            // just connected via onboarding (the selected bridge).
            let count = environment.selectedScope?.store.devices.count ?? 0
            if count > 0 {
                Text("Connected — \(count) device\(count == 1 ? "" : "s") detected.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Connected to your bridge.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .safeAreaInset(edge: .bottom) {
            Button("Get Started", action: onFinish)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppEnvironment())
}
