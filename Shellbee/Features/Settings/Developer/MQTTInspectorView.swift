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
            // Fixed-width principal keeps the segmented picker in the same
            // place regardless of how many trailing items the active tab has.
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: DesignTokens.Size.inspectorTabPickerWidth)
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

    /// Z2M log messages on `bridge/logging` carry a `level` field — surface
    /// that color on the row icon to match the raw logs view.
    var logLevelColor: Color {
        guard topic == Z2MTopics.bridgeLogging,
              let level = payload.object?["level"]?.stringValue,
              let parsed = LogLevel(rawValue: level.lowercased()) else {
            return .secondary
        }
        return parsed.color
    }

    var logLevelIcon: String {
        guard topic == Z2MTopics.bridgeLogging,
              let level = payload.object?["level"]?.stringValue,
              let parsed = LogLevel(rawValue: level.lowercased()) else {
            return "dot.radiowaves.up.forward"
        }
        return parsed.systemImage
    }
}

// MARK: - JSON syntax highlighting

enum JSONHighlighter {
    static func attributed(_ source: String) -> AttributedString {
        var out = AttributedString(source)
        out.font = .caption.monospaced()
        out.foregroundColor = .secondary

        // Keys: "<word>" : → blue
        if let regex = try? Regex<(Substring, Substring)>("\"([^\"\\\\]+)\"\\s*:") {
            for match in source.matches(of: regex) {
                let r = match.range
                if let lower = AttributedString.Index(r.lowerBound, within: out),
                   let upper = AttributedString.Index(r.upperBound, within: out) {
                    out[lower..<upper].foregroundColor = .blue
                }
            }
        }

        // String values: : "..." or array element strings → green
        if let regex = try? Regex<(Substring, Substring)>(":\\s*(\"[^\"\\\\]*\")") {
            for match in source.matches(of: regex) {
                let inner = match.output.1
                let r = inner.startIndex..<inner.endIndex
                if let lower = AttributedString.Index(r.lowerBound, within: out),
                   let upper = AttributedString.Index(r.upperBound, within: out) {
                    out[lower..<upper].foregroundColor = .green
                }
            }
        }

        // Numbers: ints / floats → orange
        if let regex = try? Regex<(Substring, Substring)>("(?<![\\w-])(-?\\d+(?:\\.\\d+)?)") {
            for match in source.matches(of: regex) {
                let inner = match.output.1
                let r = inner.startIndex..<inner.endIndex
                if let lower = AttributedString.Index(r.lowerBound, within: out),
                   let upper = AttributedString.Index(r.upperBound, within: out) {
                    out[lower..<upper].foregroundColor = .orange
                }
            }
        }

        // Booleans / null → purple
        for word in ["true", "false", "null"] {
            if let regex = try? Regex<Substring>("\\b\(word)\\b") {
                for match in source.matches(of: regex) {
                    let r = match.range
                    if let lower = AttributedString.Index(r.lowerBound, within: out),
                       let upper = AttributedString.Index(r.upperBound, within: out) {
                        out[lower..<upper].foregroundColor = .purple
                    }
                }
            }
        }

        return out
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
            // Single trailing item (a menu) keeps the principal picker stable.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        store.paused.toggle()
                    } label: {
                        Label(store.paused ? "Resume" : "Pause",
                              systemImage: store.paused ? "play.fill" : "pause.fill")
                    }
                    Button(role: .destructive) {
                        store.clear()
                    } label: {
                        Label("Clear Buffer", systemImage: "trash")
                    }
                    .disabled(store.messages.isEmpty)
                } label: {
                    if store.paused {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: "ellipsis")
                    }
                }
                .accessibilityLabel("Inspector actions")
            }
        }
        .overlay(alignment: .bottom) {
            if store.paused {
                Text("Paused")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(.orange.opacity(0.9), in: Capsule())
                    .padding(.bottom, DesignTokens.Spacing.md)
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: message.logLevelIcon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(message.logLevelColor)
                    .frame(width: DesignTokens.Size.logLevelIconWidth)
                Text(message.topic)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Spacer(minLength: 8)
                Text(message.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Text(JSONHighlighter.attributed(message.prettyPayload))
                .lineLimit(expanded ? nil : 6)
                .textSelection(.enabled)
                .padding(DesignTokens.Size.inspectorPayloadInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
                .padding(.leading, DesignTokens.Size.cardSymbol)
            if message.prettyPayload.components(separatedBy: "\n").count > 6 {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    Text(expanded ? "Show less" : "Show more")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderless)
                .padding(.leading, DesignTokens.Size.cardSymbol)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
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

            Section {
                Button("Publish") {
                    if topic.hasPrefix("bridge/request/") {
                        showWarning = true
                    } else {
                        sendNow()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .disabled(!isValid)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if let lastResult {
                Section {
                    Label(lastResult, systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    topic = ""
                    payload = ""
                    lastResult = nil
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Clear form")
                .disabled(topic.isEmpty && payload.isEmpty && lastResult == nil)
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
