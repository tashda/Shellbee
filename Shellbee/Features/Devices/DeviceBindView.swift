import SwiftUI

struct DeviceBindView: View {
    @Environment(AppEnvironment.self) private var environment
    let device: Device
    @State private var showAddSheet = false
    @State private var bindingToRemove: ParsedBinding?

    /// Multi-bridge: resolve the bridge that owns this device so reads and
    /// writes stay scoped to the right network. Falls back to the focused
    /// bridge in single-bridge mode.
    private var bridgeID: UUID? {
        environment.bridge(forDevice: device.friendlyName)?.bridgeID
    }
    private var scope: BridgeScopeBindings { environment.bridgeScope(bridgeID) }

    private var currentDevice: Device {
        scope.store.devices.first { $0.ieeeAddress == device.ieeeAddress } ?? device
    }

    private var bindings: [ParsedBinding] {
        ParsedBinding.parse(from: currentDevice.endpoints ?? [:])
    }

    var body: some View {
        List {
            if bindings.isEmpty {
                ContentUnavailableView(
                    "No Bindings",
                    systemImage: "link.badge.plus",
                    description: Text("Bind this device to control others directly over Zigbee.")
                )
            } else {
                Section("Active Bindings") {
                    ForEach(bindings) { binding in
                        bindingRow(binding)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    bindingToRemove = binding
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Bind")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddBindingSheet(device: currentDevice) { target, clusters in
                bind(to: target, clusters: clusters)
            }
        }
        .alert("Remove Binding", isPresented: Binding(
            get: { bindingToRemove != nil },
            set: { if !$0 { bindingToRemove = nil } }
        )) {
            if let b = bindingToRemove {
                Button("Remove", role: .destructive) { unbind(b); bindingToRemove = nil }
            }
            Button("Cancel", role: .cancel) { bindingToRemove = nil }
        } message: {
            if let b = bindingToRemove {
                Text("Remove the \(b.cluster) binding? This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func bindingRow(_ binding: ParsedBinding) -> some View {
        let targetDevice = scope.store.devices.first { $0.ieeeAddress == binding.targetIEEE }
        if let targetDevice {
            NavigationLink(destination: DeviceDetailView(device: targetDevice)) {
                BindingRow(binding: binding, store: scope.store)
            }
        } else {
            BindingRow(binding: binding, store: scope.store)
        }
    }

    private func bind(to target: String, clusters: [String]) {
        var payload: [String: JSONValue] = [
            "from": .string(currentDevice.friendlyName),
            "to": .string(target)
        ]
        if !clusters.isEmpty {
            payload["clusters"] = .array(clusters.map { .string($0) })
        }
        scope.send(topic: Z2MTopics.Request.deviceBind, payload: .object(payload))
    }

    private func unbind(_ binding: ParsedBinding) {
        let target = resolveTarget(binding)
        scope.send(
            topic: Z2MTopics.Request.deviceUnbind,
            payload: .object([
                "from": .string(currentDevice.friendlyName),
                "to": .string(target),
                "clusters": .array([.string(binding.cluster)])
            ])
        )
    }

    private func resolveTarget(_ binding: ParsedBinding) -> String {
        if binding.targetType == "group" {
            return scope.store.groups
                .first { $0.id == binding.groupId }?.friendlyName
                ?? "group_\(binding.groupId ?? 0)"
        }
        return scope.store.devices
            .first { $0.ieeeAddress == binding.targetIEEE }?.friendlyName
            ?? binding.targetIEEE ?? "coordinator"
    }
}

struct ParsedBinding: Identifiable {
    let id = UUID()
    let sourceEndpoint: Int
    let cluster: String
    let targetType: String
    let targetIEEE: String?
    let targetEndpoint: Int?
    let groupId: Int?

    static func parse(from endpoints: [String: JSONValue]) -> [ParsedBinding] {
        var result: [ParsedBinding] = []
        for (key, value) in endpoints {
            guard let ep = Int(key),
                  let obj = value.object,
                  let arr = obj["bindings"]?.array else { continue }
            for item in arr {
                guard let b = item.object,
                      let cluster = b["cluster"]?.stringValue,
                      let target = b["target"]?.object,
                      let type_ = target["type"]?.stringValue else { continue }
                result.append(ParsedBinding(
                    sourceEndpoint: ep, cluster: cluster, targetType: type_,
                    targetIEEE: target["ieee_address"]?.stringValue,
                    targetEndpoint: target["endpoint"]?.intValue,
                    groupId: target["id"]?.intValue
                ))
            }
        }
        return result.sorted { $0.sourceEndpoint < $1.sourceEndpoint }
    }
}

#Preview {
    NavigationStack {
        DeviceBindView(device: .preview)
            .environment(AppEnvironment())
    }
}
