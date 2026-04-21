import SwiftUI

protocol ChipRepresentable {
    var chipLabel: String { get }
    var chipIcon: String? { get }
    var chipTint: Color { get }
}
