import SwiftUI

struct PermitJoinActiveSheet: View {
    @Environment(\.dismiss) private var dismiss

    let startTime: Date?
    let totalDuration: Int
    let targetName: String?
    let onStop: () -> Void

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = remainingSeconds(at: context.date)
                VStack(spacing: 0) {
                    Spacer()
                    countdownRing(remaining: remaining)
                    Text("Via \(targetName ?? "all devices")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, DesignTokens.Spacing.xl)
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

    private func countdownRing(remaining: Int?) -> some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.15), lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress(remaining: remaining))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)

            if let remaining {
                Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                    .font(DesignTokens.Typography.permitJoinCountdown.monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(DesignTokens.Typography.permitJoinSymbol)
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
            }
        }
        .frame(width: DesignTokens.Size.permitJoinQR, height: DesignTokens.Size.permitJoinQR)
    }

    private func progress(remaining: Int?) -> CGFloat {
        guard let remaining, totalDuration > 0 else { return 1 }
        return CGFloat(remaining) / CGFloat(totalDuration)
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
        .buttonStyle(.borderedProminent)
        .tint(.red)
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
