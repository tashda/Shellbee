import Foundation

enum Z2MLogPatterns {
    static let mqttPublish = /MQTT publish: topic '(?<topic>[^']+)'/
    static let bindFailure = /Nothing to bind from '(?<from>[^']+)' to '(?<to>[^']+)'/
    static let bindSuccess = /Successfully bound '(?<from>[^']+)' to '(?<to>[^']+)'/
    static let unbind = /Nothing to unbind from '(?<from>[^']+)' to '(?<to>[^']+)'/
    static let groupAdd = /Adding '(?<device>[^']+)' to group '(?<group>[^']+)'/
    static let groupRemove = /Removing '(?<device>[^']+)' from group '(?<group>[^']+)'/
    static let publishFailure = /Publish '(?:set|get)' '(?<command>[^']+)' to '(?<device>[^']+)' failed/
    static let reportingConfigure = /Configured reporting for '(?<device>[^']+)'/
    static let otaProgress = /OTA update of '(?<device>[^']+)' at (?<percent>\d+)%/
    static let otaFinished = /OTA update of '(?<device>[^']+)' finished/
    static let singleQuoted = /'(?<name>[^']+)'/
}
