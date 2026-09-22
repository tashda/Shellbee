import SwiftUI

/// Every Activity instrument, grouped the way the resolver sees events.
/// Tapping one opens it on the stage, inside the real Activity Center,
/// Recent Events and tab bar accessory surfaces.
struct ActivityInstrumentGalleryView: View {
    @State private var scope: ActivityInstrumentGalleryScope = .all
    @State private var searchText = ""
    @State private var staged: StagedSample?

    private var samples: [ActivityInstrumentGallerySample] {
        ActivityInstrumentGalleryCatalog.filtered(scope: scope, searchText: searchText)
    }

    var body: some View {
        List {
            Section {
                Picker("Coverage", selection: $scope) {
                    ForEach(ActivityInstrumentGalleryScope.allCases) { scope in
                        Text(scope.label).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("\(samples.count) samples across \(ActivityInstrumentKind.allCases.count) instruments. Open one to see it in Activity, Recent Events and the tab bar.")
            }

            ForEach(visibleSections, id: \.self) { section in
                Section(section) {
                    ForEach(samples.filter { $0.section == section }) { sample in
                        Button {
                            staged = StagedSample(index: samples.firstIndex { $0.id == sample.id } ?? 0)
                        } label: {
                            sampleRow(sample)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle("Activity Instruments")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Find a device, change, or activity")
        .fullScreenCover(item: $staged) { staged in
            if #available(iOS 26.0, *) {
                ActivityInstrumentStageView(samples: samples, startIndex: staged.index)
            }
        }
    }

    private var visibleSections: [String] {
        ActivityInstrumentGalleryCatalog.sections.filter { section in
            samples.contains { $0.section == section }
        }
    }

    /// Feed size on the left, tab bar size on the right, so both scales are
    /// visible while scrolling.
    private func sampleRow(_ sample: ActivityInstrumentGallerySample) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.ActivityInstrument.rowSpacing) {
            ActivityInstrumentView(instrument: sample.instrument, size: DesignTokens.ActivityFeed.thumbnail)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(sample.title)
                    .font(.subheadline.weight(.semibold))
                Text(sample.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            ActivityInstrumentView(instrument: sample.instrument, size: DesignTokens.ActivityFeed.accessoryArtwork)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, DesignTokens.ActivityInstrument.rowVerticalPadding)
        .accessibilityElement(children: .combine)
    }

    private struct StagedSample: Identifiable {
        let index: Int
        var id: Int { index }
    }
}

#Preview {
    NavigationStack {
        ActivityInstrumentGalleryView()
    }
}
