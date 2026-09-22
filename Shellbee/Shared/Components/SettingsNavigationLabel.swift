import SwiftUI

/// A Settings-style navigation label with Shellbee's shared icon treatment.
/// Keeping this in one place prevents destination rows from drifting into the
/// default, un-tiled Label icon style.
struct SettingsNavigationLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            FeatureIconTile(
                symbol: systemImage,
                tint: color,
                size: DesignTokens.Size.settingsIconFrame
            )
        }
    }
}
