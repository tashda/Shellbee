import Foundation

enum CrashReportScrubber {
    private static let tokenQuery = try? NSRegularExpression(
        pattern: #"([?&](?:token|auth|key)=)[^&\s"']+"#,
        options: [.caseInsensitive]
    )

    private static let bearer = try? NSRegularExpression(
        pattern: #"(Bearer\s+)[A-Za-z0-9._\-]+"#,
        options: [.caseInsensitive]
    )

    private static let urlHost = try? NSRegularExpression(
        pattern: #"((?:wss?|https?)://)[^/\s"']+"#,
        options: [.caseInsensitive]
    )

    private static let ipv4 = try? NSRegularExpression(
        pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#
    )

    static func scrub(_ input: String) -> String {
        var output = input
        output = replace(output, regex: tokenQuery, template: "$1[redacted]")
        output = replace(output, regex: bearer, template: "$1[redacted]")
        output = replace(output, regex: urlHost, template: "$1[host]")
        output = replace(output, regex: ipv4, template: "[ip]")
        return output
    }

    private static func replace(_ input: String, regex: NSRegularExpression?, template: String) -> String {
        guard let regex else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
    }
}
