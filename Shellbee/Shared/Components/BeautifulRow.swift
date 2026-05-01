import SwiftUI

struct BeautifulRow: View {
    let label: String
    let value: JSONValue
    var unit: String? = nil

    var body: some View {
        LabeledContent {
            formattedValue
        } label: {
            Text(label).font(.subheadline).foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var formattedValue: some View {
        switch value {
        case .bool(let b):
            Text(verbatim: b ? "true" : "false")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(b ? Color.green : Color.secondary)
        case .string(let s):
            if label.lowercased().contains("color") && s.hasPrefix("#") {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Circle().fill(Color(hex: s) ?? .clear)
                        .frame(width: DesignTokens.Size.colorSwatchSize, height: DesignTokens.Size.colorSwatchSize)
                        .overlay(Circle().stroke(.secondary.opacity(DesignTokens.Opacity.subtleFill),
                                                lineWidth: DesignTokens.Size.badgeStroke))
                    Text(s).font(.caption.monospaced())
                }
            } else if s.hasPrefix("http"), let url = URL(string: s) {
                URLRow(url: url)
            } else {
                Text(s).font(.subheadline).foregroundStyle(.secondary)
            }
        case .int(let i):
            Text(verbatim: unit != nil ? "\(i)\(unit!)" : "\(i)")
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        case .double(let d):
            Text(verbatim: unit != nil ? "\(String(format: "%.1f", d))\(unit!)" : String(format: "%.1f", d))
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        case .null:
            EmptyView()
        case .array(let a):
            if a.count == 2, let lo = a[0].numberValue, let hi = a[1].numberValue {
                Text(verbatim: "\(Int(lo)) – \(Int(hi))").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            } else {
                Text("\(a.count) items").font(.caption).foregroundStyle(.secondary)
            }
        case .object(let o):
            Text("\(o.count) properties").font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct URLRow: View {
    let url: URL
    @State private var showBrowser = false

    var body: some View {
        Button {
            showBrowser = true
        } label: {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "safari")
                    .font(.caption)
                Text(url.host() ?? url.absoluteString)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBrowser) {
            SafariBrowserView(url: url)
                .ignoresSafeArea()
        }
    }
}
