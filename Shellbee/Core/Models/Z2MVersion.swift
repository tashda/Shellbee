import Foundation

struct Z2MVersion: Comparable, CustomStringConvertible, Sendable {
    let major: Int
    let minor: Int
    let patch: Int

    static func parse(_ string: String) -> Z2MVersion? {
        let parts = string
            .split(separator: ".")
            .compactMap { Int($0.prefix(while: { $0.isNumber })) }
        guard parts.count >= 2 else { return nil }
        return Z2MVersion(major: parts[0], minor: parts[1], patch: parts.count > 2 ? parts[2] : 0)
    }

    var description: String { "\(major).\(minor).\(patch)" }

    var isV2OrLater: Bool { major >= 2 }

    static func < (lhs: Z2MVersion, rhs: Z2MVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
