import SwiftUI

// Environment key injected by doc views so in-app shellbee-doc:// links that land on
// device-scoped screens (Bind, Reporting, etc.) know which device to open.
// Nil means catalog mode (Device Library) — device-scoped links fall back to an info sheet.
private struct DocContextDeviceKey: EnvironmentKey {
    static let defaultValue: Device? = nil
}

/// Phase 2 multi-bridge: companion to `docContextDevice` — the bridge id the
/// device came from. Doc views set both at the same time so device-scoped
/// in-app links resolve to the correct bridge without a name lookup.
private struct DocContextBridgeIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var docContextDevice: Device? {
        get { self[DocContextDeviceKey.self] }
        set { self[DocContextDeviceKey.self] = newValue }
    }

    var docContextBridgeID: UUID? {
        get { self[DocContextBridgeIDKey.self] }
        set { self[DocContextBridgeIDKey.self] = newValue }
    }
}

// Renders [InlineSpan] as a Text backed by AttributedString.
// Uses InlinePresentationIntent for semantic formatting (bold, italic, code)
// so the parent's .font() modifier controls size while formatting is preserved.
// Links are tappable — shellbee-doc:// links sheet-present an in-app destination;
// everything else opens in the default browser via the .link attribute.
struct DocInlineTextView: View {
    let spans: [InlineSpan]
    let sourcePath: String?
    @State private var presentedDestination: InAppDocumentationDestination?
    @Environment(\.docContextDevice) private var contextDevice: Device?
    @Environment(\.docContextBridgeID) private var contextBridgeID: UUID?
    @Environment(AppEnvironment.self) private var environment

    init(spans: [InlineSpan], sourcePath: String? = nil) {
        self.spans = spans
        self.sourcePath = sourcePath
    }

    var body: some View {
        Text(attributedString)
            .environment(\.openURL, OpenURLAction { url in
                if let destination = DocLinkResolver.destination(for: url) {
                    presentedDestination = destination
                    return .handled
                }
                return .systemAction(url)
            })
            .sheet(item: $presentedDestination) { destination in
                NavigationStack {
                    destinationView(for: destination)
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Done") { presentedDestination = nil }
                            }
                        }
                }
            }
    }

    @ViewBuilder
    private func destinationView(for destination: InAppDocumentationDestination) -> some View {
        switch destination {
        case .touchlinkGuide:
            TouchlinkGuideView(bridgeID: contextBridgeID)
        case .deviceBind:
            if let device = contextDevice, let bridgeID = contextBridgeID {
                DeviceBindView(bridgeID: bridgeID, device: device)
            } else {
                InAppLinkUnavailableView(destination: destination)
            }
        case .deviceReporting:
            if let device = contextDevice, let bridgeID = contextBridgeID {
                DeviceReportingView(bridgeID: bridgeID, device: device)
            } else {
                InAppLinkUnavailableView(destination: destination)
            }
        case .deviceSettings:
            if let device = contextDevice, let bridgeID = contextBridgeID {
                DeviceSettingsView(bridgeID: bridgeID, device: device)
            } else {
                InAppLinkUnavailableView(destination: destination)
            }
        case .deviceInfo:
            // No standalone Info screen — fall back to the device detail view.
            if let device = contextDevice, let bridgeID = contextBridgeID {
                DeviceDetailView(bridgeID: bridgeID, device: device)
            } else {
                InAppLinkUnavailableView(destination: destination)
            }
        case .settingsAdvanced, .settingsMQTT:
            InAppLinkUnavailableView(destination: destination)
        }
    }

    private var attributedString: AttributedString {
        spans.reduce(into: AttributedString()) { result, span in
            switch span {
            case .text(let s):
                result += AttributedString(s)

            case .bold(let s):
                var a = AttributedString(s)
                a.inlinePresentationIntent = .stronglyEmphasized
                result += a

            case .italic(let s):
                var a = AttributedString(s)
                a.inlinePresentationIntent = .emphasized
                result += a

            case .boldItalic(let s):
                var a = AttributedString(s)
                a.inlinePresentationIntent = [.stronglyEmphasized, .emphasized]
                result += a

            case .code(let s):
                var a = AttributedString(s)
                a.inlinePresentationIntent = .code
                result += a

            case .link(let label, let urlString):
                var a = AttributedString(label)
                a.link = DocLinkResolver.resolvedURL(for: urlString, sourcePath: sourcePath)
                result += a
            }
        }
    }
}

/// Shown when a device-scoped in-app link is tapped from a context without a device
/// (e.g., the Device Library), or when the target isn't reachable from a sheet.
private struct InAppLinkUnavailableView: View {
    let destination: InAppDocumentationDestination

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
    }

    private var title: String {
        switch destination {
        case .deviceBind: return "Bind"
        case .deviceReporting: return "Reporting"
        case .deviceSettings: return "Device Settings"
        case .deviceInfo: return "Device Info"
        case .settingsAdvanced: return "Advanced Settings"
        case .settingsMQTT: return "MQTT Settings"
        case .touchlinkGuide: return "Touchlink Guide"
        }
    }

    private var systemImage: String {
        switch destination {
        case .deviceBind: return "link"
        case .deviceReporting: return "waveform"
        case .deviceSettings, .settingsAdvanced: return "slider.horizontal.3"
        case .deviceInfo: return "info.circle"
        case .settingsMQTT: return "antenna.radiowaves.left.and.right"
        case .touchlinkGuide: return "wand.and.rays"
        }
    }

    private var message: String {
        switch destination {
        case .deviceBind, .deviceReporting, .deviceSettings, .deviceInfo:
            return "Open this device from the Devices tab to access this screen."
        case .settingsAdvanced:
            return "Open Settings › Advanced from the Settings tab."
        case .settingsMQTT:
            return "Open Settings › MQTT from the Settings tab."
        case .touchlinkGuide:
            return "Open Settings › Tools › Touchlink."
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
        DocInlineTextView(spans: [
            .text("Keep the bulb "),
            .bold("close to the coordinator"),
            .text(" during pairing.")
        ])
        DocInlineTextView(spans: [
            .text("Defaults to "),
            .code("0"),
            .text(" (no transition).")
        ])
        DocInlineTextView(spans: [
            .text("See the "),
            .link(label: "documentation", url: "https://www.zigbee2mqtt.io"),
            .text(" for details.")
        ])
    }
    .font(.subheadline)
    .padding()
}
