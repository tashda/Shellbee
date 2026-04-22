import Foundation

enum InAppDocumentationDestination: String, Identifiable {
    case touchlinkGuide

    var id: String { rawValue }
}

enum DocLinkResolver {
    private static let siteBaseURL = URL(string: "https://www.zigbee2mqtt.io/")!
    private static let inAppScheme = "shellbee-doc"

    static func resolvedURL(for rawURL: String, sourcePath: String?) -> URL? {
        if let absolute = URL(string: rawURL), let scheme = absolute.scheme?.lowercased(), scheme == "http" || scheme == "https" || scheme == inAppScheme {
            return absolute
        }

        guard let resolved = resolvedRelativeURL(for: rawURL, sourcePath: sourcePath) else {
            return URL(string: rawURL)
        }

        if destination(forResolvedURL: resolved) == .touchlinkGuide {
            let fragment = resolved.fragment.map { "#\($0)" } ?? ""
            return URL(string: "\(inAppScheme)://guide/touchlink\(fragment)")
        }

        return webURL(for: resolved)
    }

    static func destination(for url: URL) -> InAppDocumentationDestination? {
        guard url.scheme == inAppScheme else { return nil }
        if url.host == "guide", url.path == "/touchlink" {
            return .touchlinkGuide
        }
        return nil
    }

    private static func destination(forResolvedURL resolvedURL: URL) -> InAppDocumentationDestination? {
        normalize(resolvedURL.path) == "guide/usage/touchlink.md" ? .touchlinkGuide : nil
    }

    private static func resolvedRelativeURL(for rawURL: String, sourcePath: String?) -> URL? {
        guard let sourcePath else { return nil }
        guard let baseURL = URL(string: sourcePath, relativeTo: siteBaseURL) else { return nil }
        return URL(string: rawURL, relativeTo: baseURL)?.absoluteURL
    }

    private static func webURL(for resolvedURL: URL) -> URL? {
        guard var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: true) else {
            return resolvedURL
        }
        if components.path.hasSuffix(".md") {
            components.path = String(components.path.dropLast(3)) + ".html"
        }
        return components.url
    }

    private static func normalize(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
