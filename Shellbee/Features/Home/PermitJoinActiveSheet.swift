import SwiftUI

struct PermitJoinActiveSheet: View {
    @Environment(\.dismiss) private var dismiss

    let startTime: Date?
    let totalDuration: Int
    let targetName: String?
    let onStop: () -> Void

    @State private var pulseOpacity = 1.0

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = remainingSeconds(at: context.date)
                VStack(spacing: 0) {
                    Spacer()
                    activeIndicator
                    countdownDisplay(remaining: remaining)
                        .padding(.top, DesignTokens.Spacing.xl)
                    Text("Via \(targetName ?? "all devices")")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.top, DesignTokens.Spacing.sm)
                    Spacer()
                    stopButton
                        .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
            }
            .navigationTitle("Permit Join")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var activeIndicator: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .opacity(pulseOpacity)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseOpacity)
                .onAppear { pulseOpacity = 0.25 }
            Text("Active")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        }
    }

    private func countdownDisplay(remaining: Int?) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            if let remaining {
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .font(.system(size: 64, weight: .thin).monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
            }
            Text("Time remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var stopButton: some View {
        Button(role: .destructive) {
            onStop()
            dismiss()
        } label: {
            Text("Disable Join")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func remainingSeconds(at date: Date) -> Int? {
        guard let start = startTime, totalDuration > 0 else { return nil }
        let elapsed = Int(date.timeIntervalSince(start))
        return max(totalDuration - elapsed, 0)
    }
}

#Preview("Active") {
    PermitJoinActiveSheet(
        startTime: Date().addingTimeInterval(-47),
        totalDuration: 254,
        targetName: nil
    ) {}
}

#Preview("Via device") {
    PermitJoinActiveSheet(
        startTime: Date().addingTimeInterval(-12),
        totalDuration: 120,
        targetName: "Kitchen Relay"
    ) {}
}

#Preview("No timer") {
    PermitJoinActiveSheet(startTime: nil, totalDuration: 0, targetName: nil) {}
}
