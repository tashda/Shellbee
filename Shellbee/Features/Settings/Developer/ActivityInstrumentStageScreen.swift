import SwiftUI

/// The mock app screen inside the instrument stage. Each surface uses the
/// shipping component: `ActivityCard`, Home's `HomeActivityRow`, and the
/// accessory's `ActivityAccessoryContent` on an iOS 26 style tab bar.
@available(iOS 26.0, *)
struct InstrumentStageScreen: View {
    let surface: ActivityInstrumentStageView.Surface
    let items: [ActivityEventItem]
    let current: ActivityInstrumentGallerySample

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text(surface == .activity ? "Activity" : "Home")
                    .font(.largeTitle.weight(.bold))
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                if surface == .activity {
                    activityFeed
                } else {
                    homeActivitySection
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, DesignTokens.ActivityInstrument.stageContentTop)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            switch surface {
            case .tabBar: expandedBar
            case .minimized: minimizedBar
            case .activity, .home: EmptyView()
            }
        }
    }

    /// Home shows the same events as a plain List section, so the stage
    /// shows them that way too.
    private var homeActivitySection: some View {
        List {
            Section("Activity") {
                ForEach(items) { item in
                    HomeActivityRow(item: item)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        .frame(height: DesignTokens.ActivityInstrument.stageListHeight)
    }

    // MARK: - Activity Center

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: DesignTokens.ActivityFeed.cardSpacing) {
            Text("Recent")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, DesignTokens.Spacing.xs)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                ActivityCard(instrument: item.instrument, content: item.content, timestamp: item.timestamp)
            }
        }
    }

    // MARK: - Tab bar

    private func accessory(isInline: Bool) -> some View {
        ActivityAccessoryContent(
            instrument: current.instrument,
            title: current.title,
            subtitle: current.detail,
            change: current.change,
            timestamp: .now,
            identity: current.id,
            isInline: isInline
        )
    }

    private var expandedBar: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            accessory(isInline: false)
                .frame(height: DesignTokens.ActivityInstrument.stageAccessoryHeight)
                .glassEffect(.regular, in: Capsule())
            HStack(spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: 0) {
                    ForEach([AppTab.home, .devices, .groups, .settings], id: \.self) { tab in
                        VStack(spacing: DesignTokens.Spacing.xxs) {
                            tab.symbol.image
                                .font(.title3)
                            Text(tab.title)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(tab == .home ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: DesignTokens.ActivityInstrument.stageTabBarHeight)
                .glassEffect(.regular, in: Capsule())
                circleButton(AppTab.search, size: DesignTokens.ActivityInstrument.stageTabBarHeight)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.xl)
    }

    /// Scrolled: the tab bar collapses to the selected tab, and the
    /// accessory moves inline between it and search.
    private var minimizedBar: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            circleButton(AppTab.home, size: DesignTokens.ActivityInstrument.stageMinimizedHeight, selected: true)
            accessory(isInline: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: DesignTokens.ActivityInstrument.stageMinimizedHeight)
                .glassEffect(.regular, in: Capsule())
            circleButton(AppTab.search, size: DesignTokens.ActivityInstrument.stageMinimizedHeight)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.xl)
    }

    private func circleButton(_ tab: AppTab, size: CGFloat, selected: Bool = false) -> some View {
        tab.symbol.image
            .font(.title3)
            .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .frame(width: size, height: size)
            .glassEffect(.regular, in: Circle())
    }
}
