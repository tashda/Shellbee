# Shellbee

Shellbee is a native iPhone app for **Zigbee2MQTT**.

It connects directly to your Zigbee2MQTT bridge over **WebSocket**, keeps a live in-memory model of your network, and gives you an Apple-native interface for monitoring, controlling, and configuring your Zigbee setup without relying on the Zigbee2MQTT web frontend.

> All communication is real-time `{topic, payload}` JSON over WebSocket. There is no REST layer in between.

## What It Does

Shellbee is built to be a full companion app for a Zigbee2MQTT installation. It lets you:

- connect to a local or remote Zigbee2MQTT server with token-based authentication
- discover local hosts on the network and reconnect automatically when a session drops
- see bridge health, coordinator details, network information, and restart requirements
- open permit join, monitor pairing windows, and onboard new devices
- browse every joined device with native controls generated from Zigbee2MQTT exposes
- control lights, switches, covers, fans, locks, climate devices, and sensors from one app
- inspect device documentation, pairing instructions, firmware details, bindings, and reporting
- create and manage groups and scenes
- review logs and device activity in a structured UI
- edit bridge settings for MQTT, serial, network, OTA updates, logging, availability, Home Assistant, and related options
- follow connection state and OTA firmware progress with Live Activities and Dynamic Island support

## Why It Exists

Zigbee2MQTT is extremely capable, but most day-to-day interaction still happens through a browser-oriented interface. Shellbee is an attempt to make that experience feel native on iOS:

- fast to open
- readable at a glance
- touch-first for controls
- better suited to monitoring and quick adjustments from a phone

The goal is not to wrap the web UI. The goal is to present the same bridge and device data in a native SwiftUI application designed around live state, direct control, and iOS conventions.

## Core Experience

### Connection

Shellbee connects to the standard Zigbee2MQTT WebSocket endpoint:

```text
{scheme}://{host}:{port}{basePath}api?token={your-token}
```

It supports:

- local network connections over `ws://`
- public or proxied deployments over `wss://`
- saved server history
- Bonjour-based local discovery for `.local` hosts
- reconnect flows and connection status feedback

### Home

The Home screen gives a live snapshot of the bridge:

- overall connection and bridge status
- coordinator type and version information
- network metadata such as channel and PAN ID
- quick counts for devices and groups
- permit join state and restart-required warnings

### Devices

Each device gets a dedicated detail view with live state and interactive controls derived from Zigbee2MQTT exposes.

Depending on the device, Shellbee can surface:

- on or off control
- brightness and color temperature
- color selection and effects
- covers and position
- fans and speed
- climate controls
- lock actions
- sensor readings and status
- OTA firmware state

The app also includes device-specific support surfaces like:

- documentation rendering
- pairing instructions
- advanced settings
- binding management
- reporting configuration

### Groups

Shellbee supports group-focused workflows as first-class features, including:

- browsing groups
- inspecting members
- adding and removing members
- renaming and deleting groups
- working with scenes

### Settings

The app includes native settings screens for major Zigbee2MQTT configuration areas, including:

- General
- MQTT
- Adapter / serial
- Network
- Web Interface
- Log Output
- OTA Updates
- Availability
- Health Checks
- Home Assistant
- Network Access

### Live Activities

Shellbee includes ActivityKit-based Live Activities for:

- connection progress and reconnect state
- OTA firmware update progress

That makes bridge activity visible from the Lock Screen and Dynamic Island without opening the app.

## Architecture

The codebase is organized around a small set of clear layers:

```text
Core/Networking   WebSocket client, routing, connection config, discovery
Core/Models       Codable value types representing bridge, devices, logs, groups, OTA state
Core/Store        Central app state store for UI-facing data
App/              Environment, navigation, root app flow
Features/         Screen-level features such as Home, Devices, Groups, Logs, Settings
LiveActivities/   ActivityKit models and coordination
Shared/           Reusable controls and domain-specific UI components
```

Important pieces:

- `Z2MWebSocketClient` handles raw WebSocket connectivity
- `Z2MMessageRouter` turns `{topic, payload}` messages into typed app events
- `AppStore` acts as the single source of truth for mutable UI state
- `AppEnvironment` coordinates connection flow, event handling, and store updates

## Tech Stack

- Swift
- SwiftUI
- Observation (`@Observable`)
- ActivityKit
- WebSocket-based Zigbee2MQTT integration
- iOS 26 minimum target

## Running The App

### Requirements

- a running Zigbee2MQTT instance with WebSocket access
- a valid Zigbee2MQTT token
- Xcode with iOS 26 SDK support

### Local Development

1. Clone the repository.
2. Open [Shellbee.xcodeproj](/Users/k/Development/Shellbee/Shellbee.xcodeproj).
3. Build and run the `Shellbee` app target on an iPhone simulator or device.
4. Add your Zigbee2MQTT server in the app and connect.

## Status

Shellbee is under active development. The current public repository already includes the core app structure, native controls, settings flows, and Live Activity support, but the project is still evolving as the app is refined for broader public use.

## License

No license file is included yet. Until one is added, the default copyright rules apply.
