import SwiftUI

struct OnboardingTestPage: View {
    @Environment(AppEnvironment.self) private var environment
    let onContinue: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            statusIcon
                .font(.system(size: 64))

            VStack(spacing: DesignTokens.Spacing.md) {
                Text(statusTitle)
                    .font(.title2.weight(.semibold))
                if let detail = statusDetail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            }

            Spacer()

            actionButton
        }
        .onChange(of: environment.connectionState) { _, newState in
            if case .connected = newState {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.6))
                    onContinue()
                }
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch environment.connectionState {
        case .connecting, .reconnecting:
            ProgressView()
                .controlSize(.large)
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .symbolEffect(.bounce)
        case .failed, .lost:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .idle:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.secondary)
        }
    }

    private var statusTitle: String {
        switch environment.connectionState {
        case .connecting:    "Connecting"
        case .reconnecting:  "Reconnecting"
        case .connected:     "Connected"
        case .failed:        "Couldn't connect"
        case .lost:          "Lost the connection"
        case .idle:          "Waiting"
        }
    }

    private var statusDetail: String? {
        switch environment.connectionState {
        case .failed(let msg), .lost(let msg):
            return msg
        case .connected:
            return "Pulling devices and bridge info."
        default:
            return nil
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch environment.connectionState {
        case .failed, .lost:
            Button(action: onRetry) {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .frame(minWidth: 140)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        case .connected:
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        default:
            EmptyView()
        }
    }
}
