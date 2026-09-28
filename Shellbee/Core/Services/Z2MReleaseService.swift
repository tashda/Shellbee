import Foundation

/// The latest Zigbee2MQTT release tag, fetched once and shared by every
/// surface that wants to say "an update is available".
///
/// This lived in the Home bridge card's own `.task`, so every card that
/// appeared started its own request and threw the answer away when the view
/// went. One service, one cached answer, and views only read it.
@Observable
@MainActor
final class Z2MReleaseService {
    /// The latest tag as GitHub reports it — usually "2.9.3", sometimes
    /// prefixed with a "v". Callers normalise before parsing.
    private(set) var latestVersion: String?

    /// When the last request went out, successful or not. A failed fetch
    /// waits out the same interval so a broken network can't hammer an
    /// endpoint that rate-limits unauthenticated callers.
    private var lastAttempt: Date?
    private var inFlight: Task<Void, Never>?

    private static let freshness: TimeInterval = 300
    private static let endpoint = URL(string: "https://api.github.com/repos/Koenkk/zigbee2mqtt/releases/latest")!

    /// Fetches the latest tag unless a fresh one is already in hand. Safe to
    /// call from as many views as like: concurrent callers await the same
    /// request rather than starting another.
    func refresh() async {
        if let lastAttempt, Date().timeIntervalSince(lastAttempt) < Self.freshness { return }
        if let inFlight { return await inFlight.value }

        let task = Task { await fetch() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func fetch() async {
        lastAttempt = Date()

        var request = URLRequest(url: Self.endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data) else { return }

        latestVersion = release.tagName
    }

    private struct Release: Decodable {
        let tagName: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
        }
    }
}
