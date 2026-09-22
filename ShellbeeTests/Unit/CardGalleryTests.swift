import XCTest
@testable import Shellbee

final class CardGalleryTests: XCTestCase {
    @MainActor
    func testGalleryCoversEveryDeviceCategory() {
        let categories = Set(CardGalleryCatalog.samples.map { $0.device.category })
        XCTAssertEqual(categories, Set(Device.Category.allCases))
    }

    @MainActor
    func testGalleryControlContextsMatchCardCategories() {
        for sample in CardGalleryCatalog.samples {
            let device = sample.device
            let state = sample.state
            switch device.category {
            case .light:
                XCTAssertFalse(LightControlContext.contexts(for: device, state: state).isEmpty, sample.id)
            case .switchPlug:
                XCTAssertFalse(SwitchControlContext.contexts(for: device, state: state).isEmpty, sample.id)
            case .sensor:
                XCTAssertTrue(SensorSections.hasReadings(device: device, state: state), sample.id)
            case .climate:
                XCTAssertNotNil(ClimateControlContext(device: device, state: state), sample.id)
            case .cover:
                XCTAssertFalse(CoverControlContext.contexts(for: device, state: state).isEmpty, sample.id)
            case .lock:
                XCTAssertNotNil(LockControlContext(device: device, state: state), sample.id)
            case .fan:
                XCTAssertNotNil(FanControlContext(device: device, state: state), sample.id)
            case .remote, .other:
                break
            }
        }
    }

    @MainActor
    func testGallerySensorKeepsWritableSettingsAlongsideReadings() {
        let sensor = CardGalleryCatalog.samples.first { $0.device.category == .sensor }!
        let readingProperties = SensorSections.readingProperties(device: sensor.device, state: sensor.state)
        let settings = DeviceSettingsSections.exposes(for: sensor.device, claimedProperties: readingProperties)
        let settingsProperties = Set(settings.compactMap(\.property))

        XCTAssertTrue(settingsProperties.contains("fading_time"))
        XCTAssertTrue(settingsProperties.contains("indicator"))
        XCTAssertFalse(settingsProperties.contains("temperature"))
        XCTAssertFalse(settingsProperties.contains("humidity"))
    }
}
