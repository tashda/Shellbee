import Foundation

extension Device {
    /// Key into the bundled device_images store (image filename stem, e.g. "FL-230-C").
    /// Nil when the device has an explicit custom icon URL that overrides the standard path.
    nonisolated var imageKey: String? {
        if let icon = definition?.icon, let url = URL(string: icon), url.scheme != nil {
            return nil
        }
        guard let model = definition?.model else {
            return nil
        }

        return model
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }

    /// Network fallback URL for when the bundled image isn't available.
    nonisolated var imageURL: URL? {
        if let icon = definition?.icon, let url = URL(string: icon), url.scheme != nil {
            return url
        }
        guard let key = imageKey else { return nil }
        return URL(string: "https://www.zigbee2mqtt.io/images/devices/\(key).png")
    }
}
