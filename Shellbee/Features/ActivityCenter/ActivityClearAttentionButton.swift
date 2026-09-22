import SwiftUI

/// Notification Center's clear control: a round ✕ that turns into "Clear"
/// on the first tap and clears on the second. It falls back to the ✕ if
/// the second tap doesn't come, so a stray touch never clears anything.
struct ActivityClearAttentionButton: View {
    let action: () -> Void
    @State private var isArmed = false

    var body: some View {
        Button {
            if isArmed {
                isArmed = false
                action()
            } else {
                isArmed = true
            }
        } label: {
            SwiftUI.Group {
                if isArmed {
                    Text("Clear")
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    Image(systemName: "xmark")
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: DesignTokens.Size.activityClearButton, minHeight: DesignTokens.Size.activityClearButton)
        }
        .glassButtonStyleIfAvailable()
        .animation(.snappy, value: isArmed)
        .sensoryFeedback(.impact(weight: .light), trigger: isArmed)
        .task(id: isArmed) {
            guard isArmed else { return }
            try? await Task.sleep(for: .seconds(DesignTokens.Duration.activityClearConfirmWindow))
            isArmed = false
        }
        .accessibilityLabel(isArmed ? "Clear Needs Attention" : "Clear Needs Attention, double tap to confirm")
    }
}
