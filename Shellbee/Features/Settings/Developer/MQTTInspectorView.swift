import SwiftUI

struct MQTTInspectorView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selectedTab: Tab = .subscribe

    enum Tab: String, CaseIterable, Identifiable {
        case subscribe = "Subscribe"
        case publish = "Publish"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedTab {
            case .subscribe:
                SubscribeView()
            case .publish:
                PublishView()
            }
        }
        .navigationTitle("MQTT Inspector")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subscribe

private struct InspectorMessage: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let topic: String
    let payload: JSONValue

    var prettyPayload: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }
}

private struct SubscribeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var filter: String = ""
    @State private var messages: [InspectorMessage] = []
    @State private var paused: Bool = false
    @State private var bufferCap: Int = 1000

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Filter (substring of topic)", text: $filter)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button(paused ? "Resume" : "Pause") {
                    paused.toggle()
                }
                .buttonStyle(.bordered)
                Button("Clear") {
                    messages.removeAll()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if filteredMessages.isEmpty {
                ContentUnavailableView(
                    "No messages",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text(paused
                        ? "Inspector is paused."
                        : "Waiting for messages from \(environment.connectionConfig?.displayName ?? "the bridge")."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredMessages.reversed()) { msg in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(msg.topic)
                                .font(.callout.monospaced())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(msg.timestamp, format: .dateTime.hour().minute().second())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(msg.prettyPayload)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(8)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            environment.session.rawInboundTap = { topic, payload in
                guard !paused else { return }
                let msg = InspectorMessage(timestamp: .now, topic: topic, payload: payload)
                Task { @MainActor in
                    messages.append(msg)
                    if messages.count > bufferCap {
                        messages.removeFirst(messages.count - bufferCap)
                    }
                }
            }
        }
        .onDisappear {
            environment.session.rawInboundTap = nil
        }
    }

    private var filteredMessages: [InspectorMessage] {
        let f = filter.trimmingCharacters(in: .whitespaces)
        guard !f.isEmpty else { return messages }
        return messages.filter { $0.topic.contains(f) }
    }
}

// MARK: - Publish

private struct PublishView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var topic: String = ""
    @State private var payload: String = ""
    @State private var showWarning: Bool = false
    @State private var lastResult: String?

    var body: some View {
        Form {
            Section("Topic") {
                TextField("e.g. zigbee2mqtt/Office Lamp/set", text: $topic)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.callout.monospaced())
            }
            Section {
                TextEditor(text: $payload)
                    .frame(minHeight: 120)
                    .font(.callout.monospaced())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Payload")
            } footer: {
                Text("JSON object, JSON literal, or raw string. Empty payload is allowed.")
            }
            Section {
                Button {
                    if topic.hasPrefix("bridge/request/") {
                        showWarning = true
                    } else {
                        sendNow()
                    }
                } label: {
                    Label("Publish", systemImage: "paperplane.fill")
                }
                .disabled(topic.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let lastResult {
                Section("Last") {
                    Text(lastResult).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .alert("Publish to bridge/request/*?", isPresented: $showWarning) {
            Button("Publish", role: .destructive) { sendNow() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This may modify your Zigbee2MQTT configuration. Continue?")
        }
    }

    private func sendNow() {
        environment.send(topic: topic, payload: parsedPayload())
        lastResult = "Published to \(topic) at \(Date.now.formatted(date: .omitted, time: .standard))"
    }

    private func parsedPayload() -> JSONValue {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .string("") }
        if let data = trimmed.data(using: .utf8),
           let value = try? JSONDecoder().decode(JSONValue.self, from: data) {
            return value
        }
        return .string(trimmed)
    }
}

#Preview {
    NavigationStack { MQTTInspectorView() }
        .environment(AppEnvironment())
}
