import SwiftUI

struct MQTTInspectorView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selectedTab: Tab = .subscribe
    @State private var store = SubscribeStore()

    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case subscribe = "Subscribe"
        case publish = "Publish"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            switch selectedTab {
            case .subscribe:
                SubscribeView(store: store)
            case .publish:
                PublishView()
            }
        }
        .navigationTitle("MQTT Inspector")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
            }
        }
        .onAppear { store.attach(session: environment.session) }
        .onDisappear { store.detach(session: environment.session) }
    }
}

// MARK: - Model

@Observable
final class SubscribeStore {
    var messages: [InspectorMessage] = []
    var paused: Bool = false
    var filter: String = ""
    let bufferCap: Int = 1000

    func attach(session: ConnectionSessionController) {
        session.rawInboundTap = { [weak self] topic, payload in
            guard let self, !self.paused else { return }
            let msg = InspectorMessage(timestamp: .now, topic: topic, payload: payload)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.messages.append(msg)
                if self.messages.count > self.bufferCap {
                    self.messages.removeFirst(self.messages.count - self.bufferCap)
                }
            }
        }
    }

    func detach(session: ConnectionSessionController) {
        session.rawInboundTap = nil
    }

    func clear() {
        messages.removeAll()
    }

    var filtered: [InspectorMessage] {
        let f = filter.trimmingCharacters(in: .whitespaces)
        guard !f.isEmpty else { return messages }
        return messages.filter { $0.topic.localizedCaseInsensitiveContains(f) }
    }
}

struct InspectorMessage: Identifiable, Equatable {
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

// MARK: - Subscribe

private struct SubscribeView: View {
    @Bindable var store: SubscribeStore

    var body: some View {
        List {
            if store.filtered.isEmpty {
                ContentUnavailableView {
                    Label("No messages", systemImage: "dot.radiowaves.left.and.right")
                } description: {
                    Text(emptyDescription)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.filtered.reversed()) { msg in
                    MessageRow(message: msg)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $store.filter, prompt: "Filter topics")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    store.paused.toggle()
                } label: {
                    Image(systemName: store.paused ? "play.fill" : "pause.fill")
                }
                .accessibilityLabel(store.paused ? "Resume" : "Pause")
                Button {
                    store.clear()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Clear")
                .disabled(store.messages.isEmpty)
            }
        }
        .overlay(alignment: .bottom) {
            if store.paused {
                Text("Paused")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.9), in: Capsule())
                    .padding(.bottom, 12)
            }
        }
    }

    private var emptyDescription: String {
        if store.paused {
            return "Inspector is paused. Resume to continue capturing."
        }
        if !store.filter.isEmpty {
            return "No topic matches \"\(store.filter)\"."
        }
        return "Waiting for the next bridge message."
    }
}

private struct MessageRow: View {
    let message: InspectorMessage
    @State private var expanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(message.topic)
                    .font(.subheadline.monospaced().weight(.semibold))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                Text(message.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(message.prettyPayload)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(expanded ? nil : 6)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
            if message.prettyPayload.components(separatedBy: "\n").count > 6 {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    Text(expanded ? "Show less" : "Show more")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Publish

private struct PublishView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var topic: String = ""
    @State private var payload: String = ""
    @State private var showWarning: Bool = false
    @State private var lastResult: String?
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case topic, payload }

    private var isValid: Bool {
        !topic.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("e.g. zigbee2mqtt/Office Lamp/set", text: $topic)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())
                        .focused($focusedField, equals: .topic)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .payload }
                } header: {
                    Text("Topic")
                }

                Section {
                    TextEditor(text: $payload)
                        .frame(minHeight: 140)
                        .font(.callout.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .payload)
                } header: {
                    Text("Payload")
                } footer: {
                    Text("JSON object, JSON literal, or raw string. Empty payload is allowed.")
                }

                if let lastResult {
                    Section {
                        Label(lastResult, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }
            }

            Divider()

            Button {
                if topic.hasPrefix("bridge/request/") {
                    showWarning = true
                } else {
                    sendNow()
                }
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Publish")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isValid)
            .padding()
            .background(.bar)
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
        lastResult = "Published at \(Date.now.formatted(date: .omitted, time: .standard))"
        Haptics.impact(.light)
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
