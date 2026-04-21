import Foundation

extension Device {
    var imageURL: URL? {
        // 1. Try explicit icon URL from definition if available
        if let icon = definition?.icon, let url = URL(string: icon), url.scheme != nil {
            return url
        }
        
        // 2. Fallback to zigbee2mqtt.io official device images
        if let model = definition?.model {
            let sanitized = model
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "/", with: "-")
            
            return URL(string: "https://www.zigbee2mqtt.io/images/devices/\(sanitized).png")
        }
        
        return nil
    }
}
