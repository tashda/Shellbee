import XCTest

/// Color themes only reach screens that apply `.shellbeeThemedCanvas()`.
/// This scans the app's sources so a new `List` or `Form` screen can't ship
/// without it and show up as the one untinted page in a theme.
final class ThemeCoverageTests: XCTestCase {
    /// Files whose lists deliberately keep the system background.
    private let exempt: Set<String> = [
        // The iPad sidebar keeps the system sidebar material.
        "App/MainSplitView.swift",
    ]

    private let listRoot = try! NSRegularExpression(pattern: #"^\s*(List|Form)\s*[({]"#, options: .anchorsMatchLines)

    func testEveryListAndFormScreenAppliesThemedCanvas() throws {
        let appRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Shellbee")
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
            guard listRoot.firstMatch(in: body, range: range) != nil else { continue }
            scanned += 1
            if !body.contains("shellbeeThemedCanvas") && !body.contains("AdaptiveListStyle(") {
                missing.append(relative)
            }
        }

        XCTAssertGreaterThan(scanned, 50, "Expected to scan the app's list screens")
        XCTAssertEqual(missing.sorted(), [], "Apply .shellbeeThemedCanvas() to these screens")
    }
}
