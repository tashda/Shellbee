import Foundation

struct NetworkTopology: Codable, Sendable, Equatable {
    let nodes: [NetworkTopologyNode]
    let links: [NetworkTopologyLink]
}

struct NetworkTopologyNode: Codable, Sendable, Equatable, Identifiable {
    enum Role: String, Codable, Sendable {
        case coordinator = "Coordinator"
        case router = "Router"
        case endDevice = "EndDevice"
        case unknown

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            switch value.lowercased().replacingOccurrences(of: " ", with: "") {
            case "coordinator": self = .coordinator
            case "router": self = .router
            case "enddevice": self = .endDevice
            default: self = .unknown
            }
        }
    }

    let ieeeAddress: String
    let friendlyName: String
    let networkAddress: Int?
    let role: Role
    let manufacturerName: String?
    let modelID: String?

    var id: String { ieeeAddress }

    enum CodingKeys: String, CodingKey {
        case ieeeAddress = "ieeeAddr"
        case friendlyName, networkAddress, manufacturerName, modelID
        case role = "type"
    }
}

struct NetworkTopologyLink: Codable, Sendable, Equatable, Identifiable {
    let sourceIEEEAddress: String
    let targetIEEEAddress: String
    let linkQuality: Int?
    let depth: Int?
    let relationship: Int?

    var id: String { "\(sourceIEEEAddress)->\(targetIEEEAddress)" }

    private struct Endpoint: Codable {
        let ieeeAddr: String
    }

    enum CodingKeys: String, CodingKey {
        case sourceIEEEAddress = "sourceIeeeAddr"
        case targetIEEEAddress = "targetIeeeAddr"
        case linkQuality = "linkquality"
        case lqi, depth, relationship, source, target
    }

    init(
        sourceIEEEAddress: String,
        targetIEEEAddress: String,
        linkQuality: Int?,
        depth: Int? = nil,
        relationship: Int? = nil
    ) {
        self.sourceIEEEAddress = sourceIEEEAddress
        self.targetIEEEAddress = targetIEEEAddress
        self.linkQuality = linkQuality
        self.depth = depth
        self.relationship = relationship
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sourceIEEEAddress = try values.decodeIfPresent(String.self, forKey: .sourceIEEEAddress)
            ?? values.decode(Endpoint.self, forKey: .source).ieeeAddr
        targetIEEEAddress = try values.decodeIfPresent(String.self, forKey: .targetIEEEAddress)
            ?? values.decode(Endpoint.self, forKey: .target).ieeeAddr
        linkQuality = try values.decodeIfPresent(Int.self, forKey: .linkQuality)
            ?? values.decodeIfPresent(Int.self, forKey: .lqi)
        depth = try values.decodeIfPresent(Int.self, forKey: .depth)
        relationship = try values.decodeIfPresent(Int.self, forKey: .relationship)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(sourceIEEEAddress, forKey: .sourceIEEEAddress)
        try values.encode(targetIEEEAddress, forKey: .targetIEEEAddress)
        try values.encodeIfPresent(linkQuality, forKey: .linkQuality)
        try values.encodeIfPresent(depth, forKey: .depth)
        try values.encodeIfPresent(relationship, forKey: .relationship)
    }
}

struct NetworkMapResponse: Codable, Sendable {
    struct DataValue: Codable, Sendable {
        let routes: Bool?
        let type: String
        let value: NetworkTopology
    }

    let data: DataValue?
    let status: String
    let error: String?
}
