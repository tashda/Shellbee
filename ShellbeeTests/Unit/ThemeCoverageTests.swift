import XCTest

/// Color themes only reach screens that apply `.shellbeeThemedCanvas()` and
/// rows wrapped in `.shellbeeThemedRows()`. This scans the app's sources so a
/// new `List` or `Form` screen can't ship as the one untinted page in a theme.
final class ThemeCoverageTests: XCTestCase {
    /// Files whose lists deliberately keep the system background.
    private let exempt: Set<String> = [
        // The iPad sidebar keeps the system sidebar material.
        "App/MainSplitView.swift",
    ]

    /// Screens that still paint their own card background, awaiting a
    /// design review round before they move to rows.
    private let cardFillExempt: Set<String> = [
        "Features/Bridge/TouchlinkGuideView.swift",
    ]

    /// A hand-drawn card: `systemBackground` as a shape fill ignores the
    /// theme and Card Tint. Cards use `.cardSurface()`; reading screens use rows.
    private let systemBackgroundCard = try! NSRegularExpression(pattern: #"\.background\(\s*Color\(\.systemBackground\)\s*,\s*in:"#)

    private let listRoot = try! NSRegularExpression(pattern: #"^\s*(?:return\s+|let\s+\w+\s*=\s*)?(List|Form)\s*[({]"#, options: .anchorsMatchLines)

    func testNoScreenPaintsSystemBackgroundCards() throws {
        var offenders: [String] = []
        for (relative, source) in try appSources() where !cardFillExempt.contains(relative) {
            let range = NSRange(source.startIndex..., in: source)
            if systemBackgroundCard.firstMatch(in: source, range: range) != nil {
                offenders.append(relative)
            }
        }
        XCTAssertEqual(offenders.sorted(), [], "Use .cardSurface() or native List rows instead of Color(.systemBackground) cards")
    }

    private var appRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Shellbee")
    }

    private func appSources() throws -> [(String, String)] {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil))
        var sources: [(String, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let relative = String(url.path.dropFirst(appRoot.path.count + 1))
            let source = try String(contentsOf: url, encoding: .utf8)
            sources.append((relative, source.components(separatedBy: "#Preview").first ?? source))
        }
        return sources
    }

    func testEveryListAndFormScreenAppliesThemedCanvas() throws {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil))

        var missing: [String] = []
        var scanned = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let relative = String(url.path.dropFirst(appRoot.path.count + 1))
            guard !exempt.contains(relative) else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            // Previews may show a list without the app's theme.
            let body = source.components(separatedBy: "#Preview").first ?? source
            let range = NSRange(body.startIndex..., in: body)
            let lists = listRoot.numberOfMatches(in: body, range: range)
            guard lists > 0 else { continue }
            scanned += 1
            let hasCanvas = body.contains("shellbeeThemedCanvas") || body.contains("AdaptiveListStyle(")
            let themedRows = body.components(separatedBy: ".shellbeeThemedRows()").count - 1
            if !hasCanvas || themedRows < lists {
                missing.append(relative)
            }
        }

        XCTAssertGreaterThan(scanned, 50, "Expected to scan the app's list screens")
        XCTAssertEqual(missing.sorted(), [], "Apply .shellbeeThemedCanvas() and .shellbeeThemedRows() to these screens")
    }
}
