import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(OnboardingStep.completedKey) private var completed: Bool = false
    @AppStorage(OnboardingStep.storedIndexKey) private var storedIndex: Int = 0
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.top, DesignTokens.Spacing.md)

                page
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, DesignTokens.Spacing.xl)

                navigationBar
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.lg)
            }
            .navigationTitle(step == .welcome ? "" : title(for: step))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if step != .connect {
                    ToolbarItem(placement: .cancellationAction) {
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
        }
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome:  WelcomePage()
        case .concepts: ConceptsPage()
        case .connect:  OnboardingConnectPage(onConnectTapped: { step = .test })
        case .test:     OnboardingTestPage(onContinue: { step = .done }, onRetry: { step = .connect })
        case .done:     DonePage()
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(OnboardingStep.allCases) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: s == step ? 22 : 8, height: 6)
                    .animation(.spring(response: 0.3), value: step)
            }
        }
    }

    @ViewBuilder
    private var navigationBar: some View {
        HStack {
            if step != .welcome && step != .test {
                Button {
                    if let prev = OnboardingStep(rawValue: step.rawValue - 1) { step = prev }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            primaryButton
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch step {
        case .welcome, .concepts:
            Button {
                if let next = OnboardingStep(rawValue: step.rawValue + 1) { step = next }
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .connect:
            // No primary button — the connect page provides its own Connect action.
            EmptyView()
        case .test:
            EmptyView()
        case .done:
            Button {
                finish()
            } label: {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func title(for step: OnboardingStep) -> String {
        switch step {
        case .welcome:  "Welcome"
        case .concepts: "How Zigbee Works"
        case .connect:  "Connect to Z2M"
        case .test:     "Testing Connection"
        case .done:     "All Set"
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
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            VStack(spacing: DesignTokens.Spacing.md) {
                Text("Welcome to Shellbee")
                    .font(.largeTitle.weight(.bold))
                Text("A power tool for managing your Zigbee2MQTT mesh — devices, groups, OTA updates, and the network itself.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("Not a smart-home companion. For day-to-day home control, use Apple Home or another app alongside Shellbee.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tertiary)
                    .padding(.top, DesignTokens.Spacing.sm)
            }
            Spacer()
        }
    }
}

// MARK: - Concepts page

private struct ConceptsPage: View {
    private struct Concept {
        let icon: String
        let title: String
        let body: String
    }

    private let concepts: [Concept] = [
        .init(icon: "hub.hop.fill",
              title: "Coordinator",
              body: "The brain. Your USB stick or network adapter that talks Zigbee on behalf of Z2M."),
        .init(icon: "router",
              title: "Routers",
              body: "Mains-powered devices (most bulbs, plugs) that relay messages and extend coverage."),
        .init(icon: "leaf",
              title: "End Devices",
              body: "Battery-powered devices (sensors, buttons) that sleep most of the time and don't relay."),
        .init(icon: "point.3.connected.trianglepath.dotted",
              title: "The Mesh",
              body: "Coordinator + routers form a self-healing network. End devices join it through whatever's nearby.")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                ForEach(concepts, id: \.title) { concept in
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                        Image(systemName: concept.icon)
                            .font(.system(size: 32))
                            .foregroundStyle(.tint)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(concept.title).font(.headline)
                            Text(concept.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
    }
}

// MARK: - Done page

private struct DonePage: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolEffect(.bounce)
            Text("You're all set")
                .font(.largeTitle.weight(.bold))
            let count = environment.store.devices.count
            if count > 0 {
                Text("Connected — \(count) device\(count == 1 ? "" : "s") detected.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Connected to your bridge.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppEnvironment())
}
