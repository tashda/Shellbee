import SwiftUI

/// A full-screen device-detail stage for judging cards at the scale and among
/// the rows where people use them. The same fixture can be stepped through
/// without returning to the gallery list.
@available(iOS 26.0, *)
struct CardGalleryStageView: View {
    let previews: [CardGalleryPreview]
    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var surface: Surface = .devicePage
    @State private var appearance: ColorScheme = .light

    init(previews: [CardGalleryPreview], startIndex: Int) {
        self.previews = previews
        _index = State(initialValue: startIndex)
    }

    /// Which app surface the current card is staged inside. Mirrors the Live
    /// Activity gallery's Surface switch: the card doesn't change, only the
    /// screen it's judged on.
    enum Surface: String, CaseIterable, Identifiable {
        case devicePage = "Device Page"
        case logDetail = "Log Detail"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .devicePage: return "rectangle.stack"
            case .logDetail: return "clock.arrow.circlepath"
            }
        }
    }

    var body: some View {
        ZStack {
            LiveActivityPalette.stageBackdrop.ignoresSafeArea()
            CardGalleryStageDevice(appearance: appearance) {
                CardGalleryStageScreen(preview: currentPreview, surface: surface)
            }
            .padding(.top, DesignTokens.Size.liveActivityStageDeviceTop)
            .padding(.bottom, DesignTokens.Size.liveActivityStageDeviceBottom)
        }
        .overlay(alignment: .bottom) {
            CardGalleryStageControls(
                previews: previews,
                index: $index,
                surface: $surface,
                appearance: $appearance
            )
        }
        .overlay(alignment: .topLeading) {
            LiveActivityStageCloseButton { dismiss() }
                .padding(.leading, DesignTokens.Spacing.lg)
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }

    private var currentPreview: CardGalleryPreview {
        previews[min(index, previews.count - 1)]
    }
}

/// A phone-sized screen laid out at true iPhone scale, then scaled to fit the
/// stage. Its contents are normal SwiftUI Lists, so card surfaces and native
/// rows behave just as they do in the app.
@available(iOS 26.0, *)
private struct CardGalleryStageDevice<Screen: View>: View {
    let appearance: ColorScheme
    @ViewBuilder let screen: () -> Screen

    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(
                width: DesignTokens.Size.liveActivityStageScreenWidth,
                height: DesignTokens.Size.liveActivityStageScreenHeight
            )
            let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
            let shape = RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.liveActivityStageScreen,
                style: .continuous
            )

            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                screen()
                CardGalleryStageStatusBar()
            }
            .environment(\.colorScheme, appearance)
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.black, lineWidth: DesignTokens.Size.liveActivityStageBezel))
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

@available(iOS 26.0, *)
private struct CardGalleryStageStatusBar: View {
    var body: some View {
        HStack {
            Text("9:41")
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: DesignTokens.Size.liveActivityStageStatusBarGap)
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
            }
            .frame(maxWidth: .infinity)
        }
        .font(.body.weight(.semibold))
        .frame(height: DesignTokens.Size.liveActivityGalleryIslandHeight)
        .padding(.top, DesignTokens.Size.liveActivityStageIslandTop)
        .overlay {
            Capsule()
                .fill(.black)
                .frame(
                    width: DesignTokens.Size.liveActivityStageStatusBarGap,
                    height: DesignTokens.Size.liveActivityGalleryIslandHeight
                )
                .padding(.top, DesignTokens.Size.liveActivityStageIslandTop)
        }
    }
}

/// The actual grouped-list context of a device or group card. It deliberately
/// uses the same typed control cards and settings sections as detail pages.
@available(iOS 26.0, *)
private struct CardGalleryStageScreen: View {
    let preview: CardGalleryPreview
    let surface: CardGalleryStageView.Surface

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            List {
                switch surface {
                case .devicePage:
                    if let sample = preview.sample {
                        devicePage(sample)
                    } else {
                        groupPage
                    }
                case .logDetail:
                    if let sample = preview.sample {
                        logDetailPage(sample)
                    } else {
                        logDetailGroupPage
                    }
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .listSectionSpacing(DesignTokens.Spacing.lg)
        }
        .padding(.top, DesignTokens.ActivityInstrument.stageContentTop)
    }

    private var navigationBar: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
            Text(navigationBarTitle)
                .font(.body.weight(.semibold))
            Spacer(minLength: 0)
            if surface == .devicePage {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(Color(.systemGroupedBackground))
    }

    private var navigationBarTitle: String {
        switch surface {
        case .devicePage: return preview.sample == nil ? "Groups" : "Devices"
        case .logDetail: return "Activity"
        }
    }

    @ViewBuilder
    private func devicePage(_ sample: CardGallerySample) -> some View {
        let device = sample.device
        let state = sample.state
        let send: (JSONValue) -> Void = { _ in }

        DeviceCard(
            device: device,
            state: state,
            isAvailable: sample.isAvailable,
            otaStatus: nil,
            lastSeenEnabled: true
        )
        .galleryHeroRow()

        deviceControls(device: device, state: state, onSend: send)

        Section("Device Info") {
            LabeledContent("Model", value: device.definition?.model ?? "Unknown")
            LabeledContent("IEEE Address", value: device.ieeeAddress)
            LabeledContent("Network Address", value: "\(device.networkAddress)")
        }

        Section("Logs") {
            Label("State reported", systemImage: "checkmark.circle")
            Label("See All Logs", systemImage: "list.bullet")
        }
    }

    @ViewBuilder
    private func deviceControls(
        device: Device,
        state: [String: JSONValue],
        onSend: @escaping (JSONValue) -> Void
    ) -> some View {
        switch device.category {
        case .fan:
            if let context = FanControlContext(device: device, state: state) {
                Section {
                    FanControlCard(context: context, mode: .interactive, onSend: onSend)
                        .galleryCardRow()
                }
                FanReadingsSections(context: context)
                FanFeatureSections(context: context, onSend: onSend)
            } else {
                genericControls(device: device, state: state, onSend: onSend)
            }

        case .light:
            let contexts = LightControlContext.contexts(for: device, state: state)
            if !contexts.isEmpty {
                Section {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        ForEach(contexts) { context in
                            LightControlCard(
                                context: context,
                                mode: .interactive,
                                onSend: onSend,
                                rendersAdvancedSheetsInline: false
                            )
                        }
                    }
                    .galleryCardRow()
                }
                ForEach(contexts) { context in
                    LightFeatureSections(context: context, onSend: onSend)
                }
            } else {
                genericControls(device: device, state: state, onSend: onSend)
            }

        case .switchPlug:
            let contexts = SwitchControlContext.contexts(for: device, state: state)
            if !contexts.isEmpty {
                Section {
                    ExposeCardView(device: device, state: state, mode: .interactive, onSend: onSend)
                        .galleryCardRow()
                }
                if let context = contexts.first {
                    SwitchFeatureSections(device: device, context: context, state: state, onSend: onSend)
                }
            } else {
                genericControls(device: device, state: state, onSend: onSend)
            }

        case .climate:
            if let context = ClimateControlContext(device: device, state: state) {
                Section {
                    ClimateControlCard(context: context, mode: .interactive, onSend: onSend)
                        .galleryCardRow()
                }
                ClimateFeatureSections(device: device, context: context, state: state, onSend: onSend)
            } else {
                genericControls(device: device, state: state, onSend: onSend)
            }

        case .cover:
            let contexts = CoverControlContext.contexts(for: device, state: state)
            if !contexts.isEmpty {
                Section {
                    ExposeCardView(device: device, state: state, mode: .interactive, onSend: onSend)
                        .galleryCardRow()
                }
                if let context = contexts.first {
                    CoverFeatureSections(device: device, context: context, state: state, onSend: onSend)
                }
            } else {
                genericControls(device: device, state: state, onSend: onSend)
            }

        case .remote:
            RemoteSections(device: device, state: state)
            DeviceSettingsSections(
                device: device,
                state: state,
                claimedProperties: RemoteSections.claimedProperties,
                onSend: onSend
            )

        case .sensor where SensorSections.hasReadings(device: device, state: state):
            SensorSections(device: device, state: state)
            DeviceSettingsSections(
                device: device,
                state: state,
                claimedProperties: SensorSections.readingProperties(device: device, state: state),
                onSend: onSend
            )

        default:
            genericControls(device: device, state: state, onSend: onSend)
        }
    }

    @ViewBuilder
    private func genericControls(
        device: Device,
        state: [String: JSONValue],
        onSend: @escaping (JSONValue) -> Void
    ) -> some View {
        let hasPrimaryCard = ExposeCardView.hasPrimaryCard(device: device, state: state)
        if hasPrimaryCard {
            Section {
                ExposeCardView(device: device, state: state, mode: .interactive, onSend: onSend)
                    .galleryCardRow()
            }
        }
        DeviceSettingsSections(
            device: device,
            state: state,
            claimedProperties: hasPrimaryCard
                ? ExposeCardView.claimedProperties(device: device, state: state)
                : [],
            onSend: onSend
        )
    }

    /// Mirrors `LogDetailView`'s single-device layout: the compact card as
    /// one native row that would open detail, then a Changes section built
    /// from `LogChangeRows`.
    @ViewBuilder
    private func logDetailPage(_ sample: CardGallerySample) -> some View {
        Section {
            DeviceCard(
                device: sample.device,
                state: sample.state,
                isAvailable: sample.isAvailable,
                otaStatus: nil,
                displayMode: .compact
            )
        }
        changesSection(rows: sample.logChangeRows)
    }

    @ViewBuilder
    private var logDetailGroupPage: some View {
        let group = CardGalleryCatalog.group
        let devices = CardGalleryCatalog.groupMembers
        let state = CardGalleryCatalog.groupState

        Section {
            GroupCard(
                group: group,
                memberDevices: devices,
                state: state,
                membersOnCount: 2,
                displayMode: .compact
            )
        }
        changesSection(rows: CardGalleryCatalog.light.logChangeRows)
    }

    private func changesSection(rows: [LogChangeRow]) -> some View {
        Section("Changes") {
            LabeledContent("Changed") {
                Text("Today at 14:32:07")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if rows.isEmpty {
                Text("Reported again with the same values")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { LogChangeRowView(row: $0) }
            }
        }
    }

    @ViewBuilder
    private var groupPage: some View {
        let group = CardGalleryCatalog.group
        let devices = CardGalleryCatalog.groupMembers
        let state = CardGalleryCatalog.groupState
        let send: (JSONValue) -> Void = { _ in }

        GroupCard(group: group, memberDevices: devices, state: state, membersOnCount: 2)
            .galleryHeroRow()

        if let context = LightControlContext(device: devices[0], state: state) {
            Section {
                LightControlCard(context: context, mode: .interactive, onSend: send)
                    .galleryCardRow()
            }
        }

        Section("Members") {
            ForEach(Array(zip(group.members, devices)), id: \.0.ieeeAddress) { member, device in
                GroupMemberRow(member: member, device: device, state: state, isAvailable: true)
            }
        }

        Section("Scenes") {
            ForEach(group.scenes) { scene in
                LabeledContent(scene.name, value: "ID \(scene.id)")
            }
        }

        Section("Logs") {
            Label("Group state reported", systemImage: "checkmark.circle")
            Label("See All Logs", systemImage: "list.bullet")
        }
    }
}

@available(iOS 26.0, *)
private extension View {
    func galleryHeroRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    func galleryCardRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
}
