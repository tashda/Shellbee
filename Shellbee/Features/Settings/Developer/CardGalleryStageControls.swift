import SwiftUI

/// The Card Gallery's stage controls follow the Live Activity and Activity
/// Instrument galleries: step through fixtures, or choose one directly,
/// without leaving the page being judged.
@available(iOS 26.0, *)
struct CardGalleryStageControls: View {
    let previews: [CardGalleryPreview]
    @Binding var index: Int
    @Binding var surface: CardGalleryStageView.Surface
    @Binding var appearance: ColorScheme

    var body: some View {
        GlassEffectContainer(spacing: DesignTokens.Spacing.sm) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                navigator
                HStack(spacing: DesignTokens.Spacing.sm) {
                    surfaceSwitch
                    appearanceToggle
                }
            }
        }
        .tint(.white)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.sm)
    }

    private var surfaceSwitch: some View {
        HStack(spacing: 0) {
            ForEach(CardGalleryStageView.Surface.allCases) { option in
                Button {
                    withAnimation(.snappy) { surface = option }
                } label: {
                    Image(systemName: option.symbol)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.Size.liveActivityStageControl)
                        .background {
                            if surface == option {
                                Capsule().fill(.white.opacity(0.22))
                                    .padding(DesignTokens.Spacing.xs)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(surface == option ? 1 : 0.6))
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(surface == option ? .isSelected : [])
            }
        }
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var navigator: some View {
        HStack(spacing: 0) {
            step("chevron.left", label: "Previous card", by: -1)
            Menu {
                Picker("Card", selection: $index) {
                    ForEach(previews.indices, id: \.self) { position in
                        Text(previews[position].title).tag(position)
                    }
                }
            } label: {
                VStack(spacing: 0) {
                    Text(previews[index].title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(surface.rawValue) · \(index + 1) of \(previews.count)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .foregroundStyle(.white)
            step("chevron.right", label: "Next card", by: 1)
        }
        .frame(height: DesignTokens.Size.liveActivityStageControl)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: index)
    }

    private var appearanceToggle: some View {
        Button {
            withAnimation(.snappy) {
                appearance = appearance == .light ? .dark : .light
            }
        } label: {
            Image(systemName: appearance == .light ? "sun.max.fill" : "moon.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(
                    width: DesignTokens.Size.liveActivityStageControl,
                    height: DesignTokens.Size.liveActivityStageControl
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(appearance == .light ? "Light appearance" : "Dark appearance")
    }

    private func step(_ symbol: String, label: String, by offset: Int) -> some View {
        let target = index + offset
        let enabled = previews.indices.contains(target)
        return Button {
            withAnimation(.snappy) { index = target }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(
                    width: DesignTokens.Size.liveActivityStageControl,
                    height: DesignTokens.Size.liveActivityStageControl
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(enabled ? 1 : 0.3))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
