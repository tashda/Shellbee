import SwiftUI

/// A visual inventory of Shellbee's custom symbol assets and drawn icons.
struct IconGalleryView: View {
    @State private var selection: IconFamily = .all
    @State private var appearance: ColorScheme = .light
    @State private var searchText = ""

    private var samples: [IconGallerySample] {
        IconGallerySample.all.filter { sample in
            let matchesFamily = switch selection {
            case .all: true
            case .symbols: if case .symbol = sample.artwork { true } else { false }
            case .instruments: if case .instrument = sample.artwork { true } else { false }
            }
            return matchesFamily && (searchText.isEmpty
                || sample.title.localizedStandardContains(searchText)
                || sample.assetName.localizedStandardContains(searchText))
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                controls

                ForEach(IconGallerySample.sections, id: \.self) { section in
                    let sectionSamples = samples.filter { $0.section == section }
                    if !sectionSamples.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            Text(section)
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal, DesignTokens.Spacing.xs)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(sectionSamples) { sample in
                                IconGalleryCard(sample: sample)
                                    .environment(\.colorScheme, appearance)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: DesignTokens.ActivityFeed.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Icon Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Find an icon")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Picker("Icons", selection: $selection) {
                ForEach(IconFamily.allCases) { family in
                    Text(family.rawValue).tag(family)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("\(samples.count) custom icons")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Appearance", selection: $appearance) {
                    Text("Light").tag(ColorScheme.light)
                    Text("Dark").tag(ColorScheme.dark)
                }
                .pickerStyle(.menu)
                .tint(.secondary)
            }
        }
    }

    private enum IconFamily: String, CaseIterable, Identifiable {
        case all = "All"
        case symbols = "Symbols"
        case instruments = "Instruments"
        var id: String { rawValue }
    }
}

private struct IconGalleryCard: View {
    let sample: IconGallerySample

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                artwork(size: DesignTokens.IconGallery.heroSize)
                    .frame(width: DesignTokens.IconGallery.heroTile, height: DesignTokens.IconGallery.heroTile)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(sample.title)
                        .font(.headline)
                    Text(sample.assetName)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }

            Divider()

            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(DesignTokens.IconGallery.sampleSizes, id: \.self) { size in
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        artwork(size: size)
                            .frame(height: DesignTokens.IconGallery.sampleHeight)
                        Text("\(Int(size)) pt")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .cardSurface()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func artwork(size: CGFloat) -> some View {
        switch sample.artwork {
        case .symbol(let symbol):
            symbol.image
                .font(.system(size: size))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        case .instrument(let instrument):
            ActivityInstrumentView(instrument: instrument, size: size)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    NavigationStack { IconGalleryView() }
}
