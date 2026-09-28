import Foundation

struct FavoriteDeviceReference: Codable, Identifiable, Equatable {
    let bridgeID: UUID
    let ieeeAddress: String
    var friendlyName: String
    var bridgeName: String?

    var id: String { "\(bridgeID.uuidString):\(ieeeAddress)" }
}

@Observable
final class DeviceFavoritesStore {
    static let storageKey = "deviceFavorites"

    private(set) var items: [FavoriteDeviceReference] = []
    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = DeviceFavoritesStore.storageKey) {
        self.defaults = defaults
        self.storageKey = storageKey
        load()
    }

    @discardableResult
    func add(_ payload: DeviceTransferPayload) -> Bool {
        guard let bridgeID = payload.bridgeID else { return false }
        let item = FavoriteDeviceReference(
            bridgeID: bridgeID,
            ieeeAddress: payload.ieeeAddress,
            friendlyName: payload.friendlyName,
            bridgeName: payload.bridgeName
        )
        guard !items.contains(where: { $0.id == item.id }) else { return false }
        items.append(item)
        persist()
        return true
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        persist()
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.sorted().map { items[$0] }
        for index in offsets.sorted(by: >) {
            items.remove(at: index)
        }
        let removedBeforeDestination = offsets.filter { $0 < destination }.count
        let insertionIndex = min(max(destination - removedBeforeDestination, 0), items.count)
        items.insert(contentsOf: moving, at: insertionIndex)
        persist()
    }

    func move(id: String, offset: Int) {
        guard let source = items.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(source + offset, 0), items.count - 1)
        guard source != target else { return }
        let item = items.remove(at: source)
        items.insert(item, at: target)
        persist()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FavoriteDeviceReference].self, from: data)
        else { return }
        items = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
