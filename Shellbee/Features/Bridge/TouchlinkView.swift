import SwiftUI

struct TouchlinkView: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    @State private var showHueResetSheet = false
    @State private var showGuideSheet = false

    private var store: AppStore { scope.store }

    var body: some View {
        SwiftUI.Group {
            if store.touchlinkScanInProgress {
                scanningView
            } else if store.touchlinkDevices.isEmpty {
                emptyView
            } else {
                deviceList
            }
        }
        .navigationTitle("Touchlink")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showHueResetSheet) {
            PhilipsHueResetSheet(
                extendedPanId: store.bridgeInfo?.network?.extendedPanID?.stringValue ?? ""
            ) { panId, serials in
                philipsHueReset(extendedPanId: panId, serialNumbers: serials)
            }
        }
        .sheet(isPresented: $showGuideSheet) {
            NavigationStack {
                TouchlinkGuideView(bridgeID: bridgeID)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Done") { showGuideSheet = false }
                        }
                    }
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No Devices Found",
            systemImage: "dot.radiowaves.left.and.right",
            description: Text("Tap Scan to discover nearby Touchlink devices.")
        )
    }

    private var deviceList: some View {
        List(store.touchlinkDevices) { device in
            TouchlinkDeviceRow(
                device: device,
                knownName: store.devices.first { $0.ieeeAddress == device.ieeeAddress }?.friendlyName,
                identifyInProgress: store.touchlinkIdentifyInProgress,
                resetInProgress: store.touchlinkResetInProgress,
                onIdentify: identify,
                onReset: factoryReset
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showGuideSheet = true
            } label: {
                Label("Guide", systemImage: "book.pages")
            }

            Button {
                scan()
            } label: {
                Label("Scan", systemImage: "dot.radiowaves.forward")
            }
            .disabled(store.touchlinkScanInProgress)
        }

        ToolbarItem(placement: .topBarLeading) {
            Button {
                showHueResetSheet = true
            } label: {
                Label("Philips Hue Reset", systemImage: "wrench.and.screwdriver")
            }
        }
    }

    private func scan() {
        store.touchlinkScanInProgress = true
        scope.send(topic: Z2MTopics.Request.touchlinkScan, payload: .string(""))
    }

    private func identify(_ device: TouchlinkDevice) {
        store.touchlinkIdentifyInProgress = true
        scope.send(
            topic: Z2MTopics.Request.touchlinkIdentify,
            payload: .object([
                "ieee_address": .string(device.ieeeAddress),
                "channel": .int(device.channel)
            ])
        )
    }

    private func factoryReset(_ device: TouchlinkDevice) {
        store.touchlinkResetInProgress = true
        scope.send(
            topic: Z2MTopics.Request.touchlinkFactoryReset,
            payload: .object([
                "ieee_address": .string(device.ieeeAddress),
                "channel": .int(device.channel)
            ])
        )
    }

    private func philipsHueReset(extendedPanId: String, serialNumbers: [String]) {
        var params: [String: JSONValue] = [
            "serial_numbers": .array(serialNumbers.map { .string($0) })
        ]
        if !extendedPanId.isEmpty {
            params["extended_pan_id"] = .string(extendedPanId)
        }
        scope.send(
            topic: Z2MTopics.Request.action,
            payload: .object([
                "action": .string("philips_hue_factory_reset"),
                "params": .object(params)
            ])
        )
    }
}

#Preview {
    NavigationStack {
        TouchlinkView(bridgeID: UUID())
    }
    .environment(AppEnvironment())
}
