import Foundation

/// Maps Z2M `bridge/response/*` and `bridge/event` topics to friendly,
/// user-facing labels for the Activity Log. Without this, rows show raw
/// MQTT topics like `bridge/response/health_check`, which looks like
/// developer chrome and reads as "we don't know what this is".
///
/// The resolver is intentionally inert for unknown topics — callers fall
/// through to the existing generic rendering (topic-as-title) so a new
/// Z2M topic doesn't break anything; it just looks raw until it's added
/// here.
enum BridgeTopicLabel {

    /// Friendly representation of a recognized bridge topic. Title and
    /// subtitle replace the row's `summaryTitle` / `summarySubtitle`. The
    /// category drives iconography, filtering, and detail-view treatment.
    struct Display: Equatable {
        let title: String
        let subtitle: String?
        let category: LogCategory
        /// `nil` when the payload doesn't carry a status field (e.g.
        /// `bridge/event`). `true`/`false` flips iconography tint
        /// between the success colour and red.
        let isSuccess: Bool?
    }

    /// Returns a `Display` for a recognized bridge topic, or `nil` when the
    /// topic isn't one we have a friendly label for.
    static func display(for rawTopic: String, payload: [String: JSONValue]) -> Display? {
        // Z2M log lines carry the topic with the user-configurable MQTT
        // base prefix (default `zigbee2mqtt/`). Strip everything before
        // the first `bridge/` segment so the switch below can match the
        // canonical sub-topic regardless of how the user has Z2M
        // configured. Topics that don't contain `bridge/` are passed
        // through unchanged.
        let topic: String
        if let range = rawTopic.range(of: "bridge/") {
            topic = String(rawTopic[range.lowerBound...])
        } else {
            topic = rawTopic
        }

        let status = payload["status"]?.stringValue
        let isOk = status.map { $0.lowercased() == "ok" }
        let target = subjectName(in: payload)

        // bridge/event handled separately — its `type` field carries the
        // semantic, not the topic suffix.
        if topic == "bridge/event" {
            return bridgeEventDisplay(payload: payload, target: target)
        }

        // bridge/health is a periodic broadcast — distinct from
        // bridge/response/health_check (which only fires on request).
        // Its detail view uses a dedicated renderer that maps the
        // `devices` map to per-device cards, so we just need a friendly
        // label here.
        if topic == "bridge/health" {
            let healthy = payload["healthy"]?.boolValue ?? false
            return Display(
                title: "Bridge Health",
                subtitle: healthy ? "Healthy" : "Unhealthy",
                category: .bridgeActivity,
                isSuccess: healthy
            )
        }

        // bridge/response/<segments>
        switch topic {
        case "bridge/response/health_check":
            let healthy = (payload["data"]?.object?["healthy"]?.boolValue) ?? (isOk ?? false)
            return Display(
                title: "Bridge Health Check",
                subtitle: healthy ? "Healthy" : "Unhealthy",
                category: .bridgeActivity,
                isSuccess: healthy
            )
        case "bridge/response/info":
            return Display(title: "Bridge Info Refreshed", subtitle: nil,
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/options":
            return Display(title: "Bridge Options Updated", subtitle: errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/backup":
            return Display(title: "Bridge Backup", subtitle: errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/restart":
            return Display(title: "Bridge Restart", subtitle: errorOrNil(payload),
                           category: .bridgeState, isSuccess: isOk)
        case "bridge/response/permit_join":
            let value = payload["data"]?.object?["value"]?.boolValue
            let title = value == true ? "Pairing Opened" : (value == false ? "Pairing Closed" : "Pairing Window")
            return Display(title: title, subtitle: errorOrNil(payload),
                           category: .permitJoin, isSuccess: isOk)
        case "bridge/response/networkmap":
            return Display(title: "Network Map", subtitle: errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/touchlink/scan":
            return Display(title: "Touchlink Scan", subtitle: errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/touchlink/identify":
            return Display(title: "Touchlink Identify", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/touchlink/factory_reset":
            return Display(title: "Touchlink Factory Reset", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/configure":
            return Display(title: "Device Configured", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/interview":
            return Display(title: "Device Interview", subtitle: target ?? errorOrNil(payload),
                           category: .interview, isSuccess: isOk)
        case "bridge/response/device/rename":
            let to = payload["data"]?.object?["to"]?.stringValue
            return Display(title: "Device Renamed", subtitle: to ?? target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/remove":
            return Display(title: "Device Removed", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/options":
            return Display(title: "Device Options Updated", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/bind":
            return Display(title: "Device Bound", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/unbind":
            return Display(title: "Device Unbound", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/configure_reporting":
            return Display(title: "Reporting Configured", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/ota_update/check":
            return Display(title: "OTA Update Check", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/ota_update/update":
            return Display(title: "OTA Update", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/ota_update/schedule":
            return Display(title: "OTA update scheduled", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/device/ota_update/unschedule":
            return Display(title: "OTA update cancelled", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/group/add":
            return Display(title: "Group Added", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/group/remove":
            return Display(title: "Group Removed", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/group/rename":
            return Display(title: "Group Renamed", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/group/options":
            return Display(title: "Group Options Updated", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/group/members/add":
            return Display(title: "Group Member Added", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        case "bridge/response/group/members/remove":
            return Display(title: "Group Member Removed", subtitle: target ?? errorOrNil(payload),
                           category: .bridgeActivity, isSuccess: isOk)
        default:
            // Generic fallback for any unhandled bridge/response/* topic so
            // it still gets the bridge-activity treatment instead of a raw
            // topic. Pretty-prints the last path segment.
            if topic.hasPrefix("bridge/response/") {
                let suffix = String(topic.dropFirst("bridge/response/".count))
                return Display(
                    title: prettify(suffix),
                    subtitle: errorOrNil(payload),
                    category: .bridgeActivity,
                    isSuccess: isOk
                )
            }
            return nil
        }
    }

    // MARK: - bridge/event

    /// `bridge/event` carries `{type, data}`. Most of the types map to
    /// existing categories — joined/leave/announce/interview — but a few
    /// (permit_join, restart_required) belong on bridge activity.
    private static func bridgeEventDisplay(payload: [String: JSONValue], target: String?) -> Display? {
        guard let type = payload["type"]?.stringValue else { return nil }
        switch type {
        case "device_joined":
            return Display(title: "Device Joined", subtitle: target,
                           category: .deviceJoined, isSuccess: nil)
        case "device_announce":
            return Display(title: "Device Announced", subtitle: target,
                           category: .deviceAnnounce, isSuccess: nil)
        case "device_leave":
            return Display(title: "Device Left", subtitle: target,
                           category: .deviceLeave, isSuccess: nil)
        case "device_interview":
            // The `bridge/event` flavour reports interview milestones with
            // a `status` field inside `data`. Map to the interview category
            // so iconography lines up with the dedicated interview rows.
            let status = payload["data"]?.object?["status"]?.stringValue ?? ""
            let suffix = status.replacingOccurrences(of: "_", with: " ").capitalized
            let title = suffix.isEmpty ? "Device Interview" : "Interview \(suffix.lowercased())"
            return Display(title: title, subtitle: target, category: .interview, isSuccess: nil)
        case "device_options_changed":
            return Display(title: "Device Options Changed", subtitle: target,
                           category: .bridgeActivity, isSuccess: nil)
        case "scene_added", "scene_removed":
            return Display(title: type.replacingOccurrences(of: "_", with: " ").capitalized,
                           subtitle: target, category: .bridgeActivity, isSuccess: nil)
        default:
            return Display(title: prettify(type), subtitle: target,
                           category: .bridgeActivity, isSuccess: nil)
        }
    }

    // MARK: - Helpers

    /// Best-effort device/group identifier from the response payload —
    /// matches `LogEntry.resolveBridgeSubject` so the row attribution and
    /// the friendly label agree.
    private static func subjectName(in payload: [String: JSONValue]) -> String? {
        if let data = payload["data"]?.object {
            if let to = data["to"]?.stringValue { return to }
            if let id = data["id"]?.stringValue { return id }
            if let fn = data["friendly_name"]?.stringValue { return fn }
        }
        if let fn = payload["friendly_name"]?.stringValue { return fn }
        return nil
    }

    /// Surface the error message as the subtitle when the response wasn't
    /// `ok` — otherwise nil so the row collapses to a single title line.
    private static func errorOrNil(_ payload: [String: JSONValue]) -> String? {
        if payload["status"]?.stringValue?.lowercased() == "ok" { return nil }
        return payload["error"]?.stringValue
    }

    private static func prettify(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
