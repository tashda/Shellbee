import SwiftUI

enum DevicePresentationMode: String, CaseIterable, Identifiable {
    case list
    case grid
    case table

    var id: Self { self }

    var title: String {
        switch self {
        case .list: "List"
        case .grid: "Grid"
        case .table: "Table"
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .grid: "square.grid.2x2"
        case .table: "tablecells"
        }
    }
}

enum DevicePresentationPreference {
    static let storageKey = "devices.iPadPresentationMode"

    static func effectiveMode(storedValue: String, usesRegularWidth: Bool) -> DevicePresentationMode {
        guard usesRegularWidth else { return .list }
        return DevicePresentationMode(rawValue: storedValue) ?? .list
    }
}

struct DeviceAlternativePresentation: View {
    @Environment(AppEnvironment.self) private var environment
    let mode: DevicePresentationMode
    let devices: [BridgeBoundDevice]
    let selection: Binding<DeviceRoute?>?
    @Bindable var viewModel: DeviceListViewModel
    let onRename: (BridgeBoundDevice) -> Void
    let onRemove: (BridgeBoundDevice) -> Void
    let onPendingAlert: (PendingDeviceAlert, UUID) -> Void

    var body: some View {
        switch mode {
        case .list: EmptyView()
        case .grid: grid
        case .table: table
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(
                    .adaptive(minimum: DesignTokens.Size.deviceGridMinimumWidth),
                    spacing: DesignTokens.Spacing.md
                )],
                spacing: DesignTokens.Spacing.md
            ) {
                ForEach(devices) { bound in
                    DeviceGridItem(
                        bound: bound,
                        selection: selection,
                        actions: actions(for: bound)
                    )
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private var table: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                DeviceTableHeader(showsBridge: showsBridgeColumn)
                ForEach(devices) { bound in
                    DeviceTableItem(
                        bound: bound,
                        selection: selection,
                        showsBridge: showsBridgeColumn,
                        actions: actions(for: bound)
                    )
                    Divider()
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }

    private var showsBridgeColumn: Bool {
        environment.registry.orderedSessions.filter(\.isConnected).count > 1
    }

    private func actions(for bound: BridgeBoundDevice) -> DevicePresentationActions {
        let store = environment.scope(for: bound.bridgeID).store
        let device = bound.device
        let state = store.state(for: device.friendlyName)
        return DevicePresentationActions(
            state: state,
            isAvailable: store.isAvailable(device.friendlyName),
            otaStatus: store.otaStatus(for: device.friendlyName),
            isIdentifying: store.identifyInProgress.contains(device.friendlyName),
            select: { selection?.wrappedValue = DeviceRoute(bridgeID: bound.bridgeID, device: device) },
            rename: { onRename(bound) },
            remove: { onRemove(bound) },
            reconfigure: { onPendingAlert(.reconfigure(device), bound.bridgeID) },
            interview: { onPendingAlert(.interview(device), bound.bridgeID) },
            identify: { environment.scope(for: bound.bridgeID).identifyDevice(device.friendlyName) },
            checkUpdate: { viewModel.checkDeviceUpdate(device, environment: environment, bridgeID: bound.bridgeID) },
            update: state.hasUpdateAvailable
                ? { viewModel.updateDevice(device, environment: environment, bridgeID: bound.bridgeID) }
                : nil,
            schedule: state.hasUpdateAvailable
                ? { viewModel.scheduleDeviceUpdate(device, environment: environment, bridgeID: bound.bridgeID) }
                : nil,
            unschedule: {
                viewModel.unscheduleDeviceUpdate(device, environment: environment, bridgeID: bound.bridgeID)
            }
        )
    }
}

struct DevicePresentationActions {
    let state: [String: JSONValue]
    let isAvailable: Bool
    let otaStatus: OTAUpdateStatus?
    let isIdentifying: Bool
    let select: () -> Void
    let rename: () -> Void
    let remove: () -> Void
    let reconfigure: () -> Void
    let interview: () -> Void
    let identify: () -> Void
    let checkUpdate: () -> Void
    let update: (() -> Void)?
    let schedule: (() -> Void)?
    let unschedule: () -> Void
}

private struct DeviceGridItem: View {
    let bound: BridgeBoundDevice
    let selection: Binding<DeviceRoute?>?
    let actions: DevicePresentationActions

    var body: some View {
        destination {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack {
                    DeviceImageView(
                        device: bound.device,
                        isAvailable: actions.isAvailable,
                        hasUpdate: actions.state.hasUpdateAvailable,
                        otaStatus: actions.otaStatus,
                        size: DesignTokens.Size.deviceCardImage
                    )
                    Spacer()
                    availabilityLabel
                }
                Text(bound.device.friendlyName)
                    .font(.headline)
                    .lineLimit(1)
                Text(bound.device.definition?.vendor ?? bound.device.category.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: DesignTokens.Spacing.sm) {
                    metricLabel("LQI", value: actions.state.linkQuality.map(String.init) ?? "—")
                    metricLabel("Battery", value: actions.state.battery.map { "\($0)%" } ?? "—")
                    Spacer()
                    if actions.state.hasUpdateAvailable {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.blue)
                            .accessibilityLabel("OTA update available")
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(DesignTokens.Opacity.hairline))
            }
        }
        .modifier(DevicePresentationActionsModifier(bound: bound, actions: actions))
    }

    @ViewBuilder
    private func destination<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let route = DeviceRoute(bridgeID: bound.bridgeID, device: bound.device)
        if selection != nil {
            Button(action: actions.select, label: content).buttonStyle(.plain)
        } else {
            NavigationLink(value: route, label: content).buttonStyle(.plain)
        }
    }

    private var isSelected: Bool {
        selection?.wrappedValue?.bridgeID == bound.bridgeID
            && selection?.wrappedValue?.device.ieeeAddress == bound.device.ieeeAddress
    }

    private var availabilityLabel: some View {
        Image(systemName: actions.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundStyle(actions.isAvailable ? .green : .red)
            .accessibilityLabel(actions.isAvailable ? "Online" : "Offline")
    }

    private func metricLabel(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold))
        }
    }
}

private struct DeviceTableHeader: View {
    let showsBridge: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            header("Type", symbol: "square.grid.2x2", width: DesignTokens.Size.deviceTableTypeWidth)
            if showsBridge {
                header("Bridge", symbol: "antenna.radiowaves.left.and.right", width: DesignTokens.Size.deviceTableBridgeWidth)
            }
            header("Availability", symbol: "dot.radiowaves.left.and.right", width: DesignTokens.Size.deviceTableMetricWidth)
            header("LQI", symbol: "wave.3.right", width: DesignTokens.Size.deviceTableMetricWidth)
            header("Battery", symbol: "battery.50percent", width: DesignTokens.Size.deviceTableMetricWidth)
            header("OTA", symbol: "arrow.up.circle", width: DesignTokens.Size.deviceTableOTAWidth)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private func header(_ title: String, symbol: String, width: CGFloat) -> some View {
        Image(systemName: symbol)
            .frame(width: width)
            .accessibilityLabel(title)
    }
}

private struct DeviceTableItem: View {
    let bound: BridgeBoundDevice
    let selection: Binding<DeviceRoute?>?
    let showsBridge: Bool
    let actions: DevicePresentationActions

    var body: some View {
        destination {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(bound.device.friendlyName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: bound.device.category.systemImage)
                    .frame(width: DesignTokens.Size.deviceTableTypeWidth)
                    .accessibilityLabel(bound.device.category.label)
                if showsBridge {
                    Text(bound.bridgeName)
                        .font(.caption2)
                        .lineLimit(1)
                        .frame(width: DesignTokens.Size.deviceTableBridgeWidth)
                }
                Image(systemName: actions.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(actions.isAvailable ? .green : .red)
                    .frame(width: DesignTokens.Size.deviceTableMetricWidth)
                    .accessibilityLabel(actions.isAvailable ? "Online" : "Offline")
                metric(actions.state.linkQuality.map(String.init) ?? "—")
                metric(actions.state.battery.map { "\($0)%" } ?? "—")
                otaLabel
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(DesignTokens.Opacity.chipFill) : Color.clear)
        }
        .modifier(DevicePresentationActionsModifier(bound: bound, actions: actions))
    }

    @ViewBuilder
    private func destination<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let route = DeviceRoute(bridgeID: bound.bridgeID, device: bound.device)
        if selection != nil {
            Button(action: actions.select, label: content).buttonStyle(.plain)
        } else {
            NavigationLink(value: route, label: content).buttonStyle(.plain)
        }
    }

    private var isSelected: Bool {
        selection?.wrappedValue?.bridgeID == bound.bridgeID
            && selection?.wrappedValue?.device.ieeeAddress == bound.device.ieeeAddress
    }

    private func metric(_ value: String) -> some View {
        Text(value)
            .font(.caption.monospacedDigit())
            .frame(width: DesignTokens.Size.deviceTableMetricWidth)
    }

    private var otaLabel: some View {
        Image(systemName: actions.otaStatus?.isActive == true
              ? "arrow.triangle.2.circlepath"
              : actions.state.hasUpdateAvailable ? "arrow.up.circle.fill" : "checkmark.circle")
            .foregroundStyle(actions.state.hasUpdateAvailable ? .blue : .secondary)
            .frame(width: DesignTokens.Size.deviceTableOTAWidth)
            .accessibilityLabel(actions.state.hasUpdateAvailable ? "OTA update available" : "OTA current")
    }
}
