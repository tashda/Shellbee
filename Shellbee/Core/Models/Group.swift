import Foundation

struct Group: Codable, Identifiable, Sendable, Equatable, Hashable {
    let id: Int
    var friendlyName: String
    var description: String?
    var members: [GroupMember]
    var scenes: [Z2MScene]

    enum CodingKeys: String, CodingKey {
        case id, description, members, scenes
        case friendlyName = "friendly_name"
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let preview = Group(
        id: 1,
        friendlyName: "Living Room",
        description: "Main living area lights",
        members: [],
        scenes: [Z2MScene(id: 1, name: "Relax"), Z2MScene(id: 2, name: "Bright")]
    )

    static let previewWithMembers = Group(
        id: 2,
        friendlyName: "Kitchen",
        description: nil,
        members: [
            GroupMember(ieeeAddress: "0x00158d0004512345", endpoint: 1),
            GroupMember(ieeeAddress: "0x00158d0004567890", endpoint: 1),
            GroupMember(ieeeAddress: "0x00158d00045abcdef", endpoint: 1)
        ],
        scenes: []
    )
}

struct GroupMember: Codable, Sendable, Equatable {
    let ieeeAddress: String
    let endpoint: Int

    enum CodingKeys: String, CodingKey {
        case endpoint
        case ieeeAddress = "ieee_address"
    }
}

struct Z2MScene: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let name: String
}
