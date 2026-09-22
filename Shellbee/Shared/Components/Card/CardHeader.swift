import SwiftUI

/// Header row shared by every control card: a tinted SF Symbol, a
/// sentence-case title, the current value in secondary text, and optional
/// trailing accessories (a toggle or glass buttons).
struct CardHeader<Accessory: View>: View {
    let systemImage: String
    let title: String
    var value: String? = nil
    var tint: Color = .secondary
    var valueColor: Color = .secondary
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.cardHeaderSymbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))

            Text(title)
                .font(DesignTokens.Typography.cardHeaderTitle)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            if let value, !value.isEmpty {
                Text(value)
                    .font(DesignTokens.Typography.cardHeaderValue)
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: DesignTokens.Spacing.sm)

            accessory()
        }
        .accessibilityElement(children: .contain)
    }
}

extension CardHeader where Accessory == EmptyView {
    init(systemImage: String, title: String, value: String? = nil,
         tint: Color = .secondary, valueColor: Color = .secondary) {
        self.init(systemImage: systemImage, title: title, value: value,
                  tint: tint, valueColor: valueColor) { EmptyView() }
    }
}

/// Circular glass button used for card accessories (effects, startup, more).
struct CardAccessoryButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.cardHeaderSymbol)
                .frame(width: DesignTokens.Size.cardAccessoryButton,
                       height: DesignTokens.Size.cardAccessoryButton)
        }
        .buttonBorderShape(.circle)
        .glassButtonStyleIfAvailable()
        .tint(.primary)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.lg) {
        CardHeader(systemImage: "lightbulb.fill", title: "Light", value: "80 % · Pink", tint: .pink) {
            CardAccessoryButton(systemImage: "sparkles", accessibilityLabel: "Effects") {}
        }
        .cardSurface()
        CardHeader(systemImage: "power", title: "Switch", value: "On", tint: .green) {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
        .cardSurface()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
