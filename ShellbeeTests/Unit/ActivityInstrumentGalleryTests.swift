import XCTest
@testable import Shellbee

@MainActor
final class ActivityInstrumentGalleryTests: XCTestCase {
    func testEverySampleHasUniqueIdentity() {
        let ids = ActivityInstrumentGalleryCatalog.samples.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryInstrumentFamilyHasAPreview() {
        let covered = Set(ActivityInstrumentGalleryCatalog.samples.map(\.instrument.kind))
        XCTAssertEqual(covered, Set(ActivityInstrumentKind.allCases))
    }

    func testEveryDeviceCategoryHasAPreview() {
        let covered = Set(ActivityInstrumentGalleryCatalog.samples.compactMap(\.deviceCategory))
        XCTAssertEqual(covered, Set(Device.Category.allCases))
    }

    func testEveryTopologyTypeHasAPreview() {
        let covered = Set(ActivityInstrumentGalleryCatalog.samples.compactMap(\.topologyType))
        XCTAssertEqual(covered, ActivityInstrumentGalleryCatalog.requiredTopologyTypes)
    }

    func testEveryZ2MExposeShapeHasAPreview() {
        let covered = Set(ActivityInstrumentGalleryCatalog.samples.compactMap(\.exposeType))
        XCTAssertEqual(covered, ActivityInstrumentGalleryCatalog.requiredExposeTypes)
    }

    func testEveryLogCategoryHasAPreview() {
        let covered = Set(ActivityInstrumentGalleryCatalog.samples.compactMap(\.logCategory))
        XCTAssertEqual(covered, Set(LogCategory.allCases))
    }

    func testEverySeverityHasAPreview() {
        let covered = Set(ActivityInstrumentGalleryCatalog.samples.map(\.instrument.severity))
        XCTAssertEqual(covered, Set(ActivityInstrumentSeverity.allCases))
    }

    func testBridgeRequestCoverageMatchesShellbeeRequests() {
        let expected: Set<String> = [
            "action", "backup", "device/bind", "device/configure", "device/configure_reporting",
            "device/interview", "device/options", "device/ota_update/check",
            "device/ota_update/schedule", "device/ota_update/unschedule", "device/ota_update/update",
            "device/remove", "device/rename", "device/unbind", "devices", "group/add",
            "group/members/add", "group/members/remove", "group/options", "group/remove",
            "group/rename", "groups", "health_check", "info", "install_code/add", "networkmap",
            "options", "permit_join", "restart", "touchlink/factory_reset", "touchlink/identify",
            "touchlink/scan"
        ]
        let covered = Set(
            ActivityInstrumentGalleryCatalog.samples
                .filter { $0.section == "Bridge Requests" }
                .compactMap(\.bridgeTopic)
                .map { $0.replacingOccurrences(of: "bridge/response/", with: "") }
                .filter { $0 != "custom_response" }
        )
        XCTAssertEqual(covered, expected)
    }

    func testUnknownPropertiesAndFutureEventsHaveFallbacks() {
        let fallbackIDs = Set(
            ActivityInstrumentGalleryCatalog.samples
                .filter { $0.instrument.kind == .unknown }
                .map(\.id)
        )
        XCTAssertTrue(fallbackIDs.contains("device.other"))
        XCTAssertTrue(fallbackIDs.contains("change.custom"))
        XCTAssertTrue(fallbackIDs.contains("bridge.custom_response"))
        XCTAssertTrue(fallbackIDs.contains("event.unknown-event"))
    }
}
