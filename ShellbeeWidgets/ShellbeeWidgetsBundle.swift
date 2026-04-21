import SwiftUI
import WidgetKit

@main
struct ShellbeeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ConnectionActivityWidget()
        OTAUpdateActivityWidget()
    }
}
