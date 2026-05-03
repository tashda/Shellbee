import SwiftUI

struct BridgeLogView: View {
    @Environment(AppEnvironment.self) private var environment
    let viewModel: BridgeLogViewModel

    private var connectedSessions: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    /// Sessions whose raw log entries should be displayed. With an explicit
    /// `bridgeFilter`, just that session; otherwise every connected session
    /// (merged newest-first), so multi-bridge users don't silently see only
    /// one bridge's lines.
    private var displayedSessions: [BridgeSession] {
        if let id = viewModel.bridgeFilter,
           let session = connectedSessions.first(where: { $0.bridgeID == id }) {
            return [session]
        }
        return connectedSessions
    }

    private var mergedEntries: [BridgeBoundLogEntry] {
        displayedSessions.flatMap { session -> [BridgeBoundLogEntry] in
            viewModel.filteredEntries(store: session.store).map { entry in
                BridgeBoundLogEntry(
                    bridgeID: session.bridgeID,
                    bridgeName: session.displayName,
                    entry: entry
                )
            }
        }
        .sorted { $0.entry.timestamp > $1.entry.timestamp }
    }

    private var hasAnyRawEntries: Bool {
        displayedSessions.contains { !$0.store.rawLogEntries.isEmpty }
    }

    var body: some View {
        let entries = mergedEntries
        List {
            ForEach(entries) { item in
                NavigationLink(destination: BridgeLogDetailView(entry: item.entry)) {
                    BridgeLogRowView(entry: item.entry)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(BridgeRowLeadingBar(bridgeID: item.bridgeID))
            }
        }
        .listStyle(.plain)
        .overlay {
            if displayedSessions.isEmpty || !hasAnyRawEntries {
                ContentUnavailableView(
                    "No Log Entries",
                    systemImage: "terminal",
                    description: Text("Raw zigbee2mqtt log lines will appear here in real time.")
                )
            } else if entries.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
    }
}

struct BridgeLogRowView: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.summaryRowVerticalPadding) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: entry.level.systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(entry.level.color)
                    .frame(width: DesignTokens.Size.logLevelIconWidth, alignment: .center)
                if let topic = mqttTopic {
                    Text(topic)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else if let ns = entry.namespace {
                    Text(ns)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(entry.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(mqttTopic != nil ? .secondary : .primary)
                .lineLimit(3)
                .padding(.leading, DesignTokens.Size.logLevelIconWidth + DesignTokens.Spacing.sm)
        }
    }

    private var mqttTopic: String? {
        entry.message.firstMatch(of: /topic '([^']+)'/).map { String($0.1) }
    }
}

struct BridgeLogDetailView: View {
    let entry: LogEntry
    @State private var prettyPrint = true
    @AppStorage("bridgeLogDetailFontSize") private var fontSize: Double = Double(DesignTokens.Size.bridgeLogDetailFontDefault)

    private static let minFontSize: Double = Double(DesignTokens.Size.bridgeLogDetailFontMin)
    private static let maxFontSize: Double = Double(DesignTokens.Size.bridgeLogDetailFontMax)

    // Returns pretty-printed version of any JSON found in the message,
    // handling both bare JSON and the Z2M log format: "... payload '{...}'"
    private var prettyMessage: String? {
        let msg = entry.message

        // Case 1: entire message is JSON
        if let data = msg.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: pretty, encoding: .utf8) {
            return str
        }

        // Case 2: Z2M log line with embedded payload '{ ... }'
        guard let payloadRange = msg.range(of: "payload '"),
              let braceRange = msg.range(of: "{", range: payloadRange.upperBound..<msg.endIndex),
              msg.hasSuffix("}'") else { return nil }

        let jsonEnd = msg.index(msg.endIndex, offsetBy: -2)
        let jsonStr = String(msg[braceRange.lowerBound...jsonEnd])

        guard let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let prettyStr = String(data: pretty, encoding: .utf8) else { return nil }

        let prefix = String(msg[msg.startIndex..<braceRange.lowerBound])
        return prefix + prettyStr + "'"
    }

    private var formattedMessage: String {
        prettyPrint ? (prettyMessage ?? entry.message) : entry.message
    }

    private var prettyAttributed: AttributedString? {
        let msg = entry.message

        if let data = msg.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            return JSONSyntaxRenderer.render(obj, indent: 0)
        }

        guard let payloadRange = msg.range(of: "payload '"),
              let braceRange = msg.range(of: "{", range: payloadRange.upperBound..<msg.endIndex),
              msg.hasSuffix("}'") else { return nil }

        let jsonEnd = msg.index(msg.endIndex, offsetBy: -2)
        let jsonStr = String(msg[braceRange.lowerBound...jsonEnd])

        guard let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else { return nil }

        let prefix = String(msg[msg.startIndex..<braceRange.lowerBound])
        var out = AttributedString(prefix)
        out.append(JSONSyntaxRenderer.render(obj, indent: 0))
        out.append(AttributedString("'"))
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: entry.level.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.level.color)
                    Text(entry.level.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.level.color)
                    Spacer()
                    Text(entry.timestamp, format: .dateTime.hour().minute().second())
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let ns = entry.namespace {
                    Text(ns)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Divider()
                if prettyPrint, let attr = prettyAttributed {
                    Text(attr)
                        .font(.system(size: fontSize, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(entry.message)
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .navigationTitle("Raw Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    fontSize = max(Self.minFontSize, fontSize - 1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .disabled(fontSize <= Self.minFontSize)

                Button {
                    fontSize = min(Self.maxFontSize, fontSize + 1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(fontSize >= Self.maxFontSize)

                if prettyMessage != nil {
                    Button {
                        prettyPrint.toggle()
                    } label: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                    .tint(prettyPrint ? .accentColor : .secondary)
                }
            }
        }
    }
}

private enum JSONSyntaxRenderer {
    static func render(_ value: Any, indent: Int) -> AttributedString {
        let pad = String(repeating: "  ", count: indent)
        let nextPad = String(repeating: "  ", count: indent + 1)
        var out = AttributedString("")

        if let dict = value as? [String: Any] {
            if dict.isEmpty {
                out.append(punct("{}")); return out
            }
            out.append(punct("{\n"))
            let keys = dict.keys.sorted()
            for (i, k) in keys.enumerated() {
                out.append(AttributedString(nextPad))
                var key = AttributedString("\"\(escape(k))\"")
                key.foregroundColor = DesignTokens.JSONSyntax.key
                out.append(key)
                out.append(punct(": "))
                out.append(render(dict[k] ?? NSNull(), indent: indent + 1))
                if i < keys.count - 1 { out.append(punct(",")) }
                out.append(AttributedString("\n"))
            }
            out.append(AttributedString(pad))
            out.append(punct("}"))
        } else if let arr = value as? [Any] {
            if arr.isEmpty {
                out.append(punct("[]")); return out
            }
            out.append(punct("[\n"))
            for (i, v) in arr.enumerated() {
                out.append(AttributedString(nextPad))
                out.append(render(v, indent: indent + 1))
                if i < arr.count - 1 { out.append(punct(",")) }
                out.append(AttributedString("\n"))
            }
            out.append(AttributedString(pad))
            out.append(punct("]"))
        } else if let s = value as? String {
            var v = AttributedString("\"\(escape(s))\"")
            v.foregroundColor = DesignTokens.JSONSyntax.string
            out.append(v)
        } else if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                var v = AttributedString(n.boolValue ? "true" : "false")
                v.foregroundColor = DesignTokens.JSONSyntax.bool
                out.append(v)
            } else {
                var v = AttributedString(n.stringValue)
                v.foregroundColor = DesignTokens.JSONSyntax.number
                out.append(v)
            }
        } else if value is NSNull {
            var v = AttributedString("null")
            v.foregroundColor = DesignTokens.JSONSyntax.null
            out.append(v)
        } else {
            out.append(AttributedString(String(describing: value)))
        }
        return out
    }

    private static func punct(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        a.foregroundColor = DesignTokens.JSONSyntax.punctuation
        return a
    }

    private static func escape(_ s: String) -> String {
        var r = ""
        for ch in s {
            switch ch {
            case "\\": r += "\\\\"
            case "\"": r += "\\\""
            case "\n": r += "\\n"
            case "\r": r += "\\r"
            case "\t": r += "\\t"
            default: r.append(ch)
            }
        }
        return r
    }
}
