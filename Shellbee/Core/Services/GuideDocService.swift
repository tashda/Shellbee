import Foundation
import OSLog

actor GuideDocService {
    static let shared = GuideDocService()

    private nonisolated let log = Logger(subsystem: "dev.echodb.shellbee", category: "GuideDocService")
    private var cache: [String: ParsedGuideDoc] = [:]
    private nonisolated let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private init() {}

    func guide(at sourcePath: String, z2mVersion: String) async throws -> ParsedGuideDoc {
        let branch = z2mVersion.isStableZ2MVersion ? "master" : "dev"
        let key = "\(sourcePath)@\(branch)"

        if let cached = cache[key] {
            return cached
        }

        guard let url = URL(string: "https://raw.githubusercontent.com/Koenkk/zigbee2mqtt.io/\(branch)/docs/\(sourcePath)") else {
            throw DeviceDocError.notFound
        }

        log.debug("fetching guide \(url)")

        do {
            let (data, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status == 200 else {
                throw DeviceDocError.notFound
            }

            let raw = String(data: data, encoding: .utf8) ?? ""
            let title = guideTitle(in: raw) ?? "Guide"
            let parsed = DocParser.parse(prepareGuideMarkdown(raw))
            let guide = ParsedGuideDoc(title: title, sourcePath: sourcePath, parsed: parsed)
            cache[key] = guide
            return guide
        } catch let error as DeviceDocError {
            throw error
        } catch {
            log.error("guide fetch failed for \(key): \(error)")
            throw DeviceDocError.networkError(error)
        }
    }

    private func guideTitle(in raw: String) -> String? {
        raw
            .components(separatedBy: .newlines)
            .first { $0.hasPrefix("# ") }
            .map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func prepareGuideMarkdown(_ raw: String) -> String {
        let lines = raw.components(separatedBy: .newlines)
        var output: [String] = []
        var currentAdmonition: String?
        var admonitionLines: [String] = []
        var insertedOverview = false

        func flushAdmonition() {
            guard let currentAdmonition else { return }
            let label = currentAdmonition.capitalized
            let body = admonitionLines
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty {
                output.append("> \(label): \(body)")
                output.append("")
            }
            admonitionLines.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == ":::" {
                flushAdmonition()
                currentAdmonition = nil
                continue
            }

            if trimmed.hasPrefix(":::") {
                flushAdmonition()
                currentAdmonition = trimmed.replacingOccurrences(of: ":::", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                admonitionLines.removeAll()
                continue
            }

            if currentAdmonition != nil {
                admonitionLines.append(trimmed)
                continue
            }

            if !insertedOverview, trimmed.hasPrefix("# ") {
                output.append(line)
                output.append("")
                output.append("## Overview")
                insertedOverview = true
                continue
            }

            output.append(line)
        }

        flushAdmonition()
        return output.joined(separator: "\n")
    }
}

extension String {
    nonisolated var isStableZ2MVersion: Bool {
        let parts = split(separator: ".")
        return parts.count == 3 && parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }
}
