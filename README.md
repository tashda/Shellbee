<p align="center">
  <img src="Shellbee/Assets.xcassets/AppIcon.appiconset/light_shellby-iOS-Default-1024x1024@1x.png" alt="Shellbee app icon" width="160" height="160" style="border-radius: 28px;" />
</p>

<h1 align="center">Shellbee</h1>

<p align="center">A native iOS app for Zigbee2MQTT.</p>

Shellbee connects directly to a Zigbee2MQTT bridge over WebSocket and gives you a SwiftUI interface for monitoring and controlling your Zigbee network.

## Features

- Connect to local or remote bridges (`ws://` and `wss://`), with saved servers and Bonjour discovery for `.local` hosts.
- Home view with bridge status, coordinator info, network details, and device/group counts.
- Device detail screens with controls generated from Z2M exposes: on/off, brightness, color, covers, fans, climate, locks, and sensor readings.
- Groups and scenes: browse, edit members, rename, delete.
- Bridge settings screens for MQTT, serial, network, OTA, logging, availability, health checks, Home Assistant, and frontend options.
- Logs view and bundled offline device documentation.
- Live Activities for connection state and OTA progress.

## Architecture

```text
Core/Networking   WebSocket client, routing, discovery
Core/Models       Codable types for bridge, devices, groups, logs, OTA
Core/Store        AppStore — single source of truth for UI state
App/              AppEnvironment, navigation, root flow
Features/         Home, Devices, Groups, Logs, Settings
LiveActivities/   ActivityKit coordination
Shared/           Reusable controls
```

- `Z2MWebSocketClient` owns the socket.
- `Z2MMessageRouter` maps `{topic, payload}` messages to typed events.
- `AppStore` holds mutable state; `AppEnvironment` wires it together.

## Requirements

- Xcode with the iOS 26 SDK
- A running Zigbee2MQTT instance with WebSocket access and a valid token

## Build

1. Clone the repo and open `Shellbee.xcodeproj`.
2. For simulator builds, run the `Shellbee` target as-is.
3. For device builds or archives, copy `Config/BuildSettings.local.example.xcconfig` to `Config/BuildSettings.local.xcconfig` and set `APP_DEVELOPMENT_TEAM` and bundle identifiers.
4. Launch the app and add your Zigbee2MQTT server.

Signing values stay in the gitignored local xcconfig. Auth tokens are stored in Keychain-backed storage, not `UserDefaults`.

## License

AGPL-3.0. See `LICENSE`.
