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
        .onAppear { if let session = environment.session { store.attach(session: session) } }
        .onDisappear { if let session = environment.session { store.detach(session: session) } }
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
                    .background(.orange.opacity(DesignTokens.Opacity.banner), in: Capsule())
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
                Spacer(minLength: DesignTokens.Spacing.sm)
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
                    withAnimation(.easeInOut(duration: DesignTokens.Duration.quickFade)) { expanded.toggle() }
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
