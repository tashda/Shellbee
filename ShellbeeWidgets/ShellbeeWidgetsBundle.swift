import SwiftUI
import WidgetKit

@main
struct ShellbeeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OTAUpdateActivityWidget()
        PermitJoinActivityWidget()
        BridgeOperationActivityWidget()
    }
}
