import Foundation

struct Contributor: Codable, Identifiable, Hashable {
    let id: Int
    let login: String
    let avatarURL: URL
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
    }
}

actor ContributorsService {
    static let shared = ContributorsService()

    private static let endpoint = URL(string: "https://api.github.com/repos/tashda/Shellbee/contributors?per_page=100")!
    private static let excludedLogins: Set<String> = ["tashda", "claude", "github-actions[bot]"]

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("contributors.json")
    }()

    nonisolated func loadCached() -> [Contributor] {
        guard let data = try? Data(contentsOf: cacheURL),
              let list = try? JSONDecoder().decode([Contributor].self, from: data) else {
            return []
        }
        return list
    }

    func refresh() async -> [Contributor] {
        var request = URLRequest(url: Self.endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode([Contributor].self, from: data) else {
            return loadCached()
        }

        let filtered = decoded.filter { contributor in
            !Self.excludedLogins.contains(contributor.login) &&
            !contributor.login.hasSuffix("[bot]")
        }

        if let encoded = try? JSONEncoder().encode(filtered) {
            try? encoded.write(to: cacheURL, options: .atomic)
        }
        return filtered
    }
}
