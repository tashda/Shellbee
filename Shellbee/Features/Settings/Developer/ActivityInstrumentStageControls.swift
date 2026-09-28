import SwiftUI

/// The instrument stage's floating controls, styled like the Live Activity
/// stage: a sample navigator, then surface and appearance switches.
@available(iOS 26.0, *)
struct ActivityInstrumentStageControls: View {
    let samples: [ActivityInstrumentGallerySample]
    @Binding var index: Int
    @Binding var surface: ActivityInstrumentStageView.Surface
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

    // MARK: - Navigator

    private var navigator: some View {
        HStack(spacing: 0) {
            step("chevron.left", label: "Previous instrument", by: -1)
            Menu {
                ForEach(sections, id: \.self) { section in
                    Section(section) {
                        ForEach(samples.indices.filter { samples[$0].section == section }, id: \.self) { position in
                            Button(samples[position].title) { index = position }
                        }
                    }
                }
            } label: {
                VStack(spacing: 0) {
                    Text(samples[index].title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(samples[index].section) · \(index + 1) of \(samples.count)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .foregroundStyle(.white)
            step("chevron.right", label: "Next instrument", by: 1)
        }
        .frame(height: DesignTokens.Size.liveActivityStageControl)
        .glassEffect(.regular.interactive(), in: Capsule())
        .sensoryFeedback(.selection, trigger: index)
    }

    private var sections: [String] {
        var seen = Set<String>()
        return samples.compactMap { seen.insert($0.section).inserted ? $0.section : nil }
    }

    private func step(_ symbol: String, label: String, by offset: Int) -> some View {
        let target = index + offset
        let enabled = samples.indices.contains(target)
        return Button {
            withAnimation(.snappy) { index = target }
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: DesignTokens.Size.liveActivityStageControl, height: DesignTokens.Size.liveActivityStageControl)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(enabled ? 1 : 0.3))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: - Switches

    private var surfaceSwitch: some View {
        HStack(spacing: 0) {
            ForEach(ActivityInstrumentStageView.Surface.allCases) { option in
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

    private var appearanceToggle: some View {
        Button {
            withAnimation(.snappy) { appearance = appearance == .light ? .dark : .light }
        } label: {
            Image(systemName: appearance == .light ? "sun.max.fill" : "moon.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: DesignTokens.Size.liveActivityStageControl, height: DesignTokens.Size.liveActivityStageControl)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(appearance == .light ? "Light appearance" : "Dark appearance")
    }
}
