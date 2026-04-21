struct TouchlinkDevice: Codable, Identifiable, Sendable, Equatable {
    let ieeeAddress: String
    let channel: Int

    var id: String { ieeeAddress }

    enum CodingKeys: String, CodingKey {
        case ieeeAddress = "ieee_address"
        case channel
    }
}
