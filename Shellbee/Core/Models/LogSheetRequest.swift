import Foundation

struct LogSheetRequest: Identifiable, Hashable {
    let id = UUID()
    let entryIDs: [UUID]

    var isSingle: Bool { entryIDs.count == 1 }
}
