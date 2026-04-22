# Privacy Policy for Shellbee

_Last updated: 2026-04-22_

Shellbee ("the app") is a native iOS/iPadOS client for [Zigbee2MQTT](https://www.zigbee2mqtt.io). This policy explains what data the app handles and how it is stored.

## Summary

Shellbee communicates directly with the Zigbee2MQTT bridge you configure. There are no advertising SDKs, no tracking, no product analytics, and no developer-operated backend for app data.

The only exception is **optional, opt-in crash reporting** via [Sentry](https://sentry.io). Crash reports are never sent without your explicit permission. You can share individual crashes only, turn on automatic sharing, or never send anything. Details below.

## Data the app handles

All data stays on your device or is exchanged directly between your device and your Zigbee2MQTT bridge.

### Information you provide

To connect to your bridge, you provide:

- Server address (hostname or IP, port, path, scheme)
- Authentication token for your Zigbee2MQTT instance
- An optional label for each saved server

This information is stored locally on your device. Authentication tokens are stored in the iOS Keychain. Server metadata and app preferences are stored in local app storage. None of it is transmitted anywhere other than to the bridge you chose to connect to.

### Information exchanged with your Zigbee2MQTT bridge

While connected, the app exchanges real-time Zigbee2MQTT messages with your bridge over WebSocket, including:

- Bridge, coordinator, and network status
- Device lists, exposes, state, and settings
- Group and scene data
- Logs produced by your bridge
- Commands you issue (on/off, brightness, configuration changes, etc.)

This traffic flows directly between your device and your bridge. The developer of Shellbee does not operate any intermediate server and does not see any of this traffic.

### Local network discovery

When you use the "find on local network" feature, the app uses Apple's Bonjour/mDNS APIs to discover `.local` hosts on the network you are currently connected to. Discovery results are used only to populate the in-app server picker and are not transmitted off the device.

iOS will prompt you for Local Network permission the first time this is used. You can revoke it at any time in **Settings → Privacy & Security → Local Network**.

## Crash reporting (opt-in)

If, and only if, you opt in, the app sends crash reports to [Sentry](https://sentry.io) — a crash-reporting service that acts as a data processor for the developer. How it works:

- **Default: off.** Nothing is ever sent automatically out of the box.
- When the app crashes, a summary of the error and a short stack trace is saved **locally on your device**. Nothing leaves the device at this point.
- On the next launch, the app asks: "Shellbee crashed last time. Share the report with the developer?" You can **Share** this one report, choose **Always share** future reports, or **Discard**.
- **Always share** can be toggled at any time in **Settings → Feedback → Automatically share crash reports**.

**What a crash report contains:**

- Error type, message, and a short stack trace of the crash
- App version and build number
- iOS version and device model (e.g., "iPhone 15 Pro")

**What a crash report does _not_ contain:**

- Your bridge's hostname, IP address, or URL (scrubbed before sending)
- Your Zigbee2MQTT authentication token (scrubbed before sending)
- Your Zigbee device names, IDs, or state
- Any personal identifier, user ID, or contact information
- Advertising identifier (IDFA)
- Location, photos, contacts, or any other OS-level personal data

The app applies a redactor before submitting any report, replacing URLs, IP addresses, and bearer/auth tokens with placeholder strings. Reports are stored by Sentry under their [privacy policy](https://sentry.io/privacy/).

If you opt out (the default), no data is transmitted to Sentry. Any locally stored crash summary is deleted when you tap Discard or uninstall the app.

## Data the app does _not_ collect

Shellbee does not collect, store, or transmit:

- Analytics, usage metrics, or telemetry (aside from the opt-in crash reporting above)
- Advertising identifiers
- Contacts, photos, location, microphone, camera, health, or HomeKit data
- Any personally identifying information

No third-party analytics, advertising, or tracking SDKs are integrated into the app. The only third-party SDK included is Sentry for the opt-in crash reporting described above.

## Apple-provided diagnostics

If you have enabled **Share With App Developers** in iOS (**Settings → Privacy & Security → Analytics & Improvements**), Apple may provide the developer with aggregated, anonymized crash and performance reports through App Store Connect. This data is collected and anonymized by Apple, not by the app, and contains no personal information. You can disable this at any time in iOS Settings.

## Permissions the app requests

- **Local Network** — used only for Bonjour discovery of Zigbee2MQTT bridges on your local network.
- **Notifications** (optional) — used for Live Activities and alerts related to connection state and OTA firmware progress on the bridge you connect to.

The app does not request access to contacts, photos, location, microphone, camera, health, or HomeKit data.

## Data retention and deletion

All app data is stored locally on your device. You can remove it at any time by:

- Deleting individual saved servers from within the app, or
- Deleting the app, which removes all locally stored configuration, including tokens in the Keychain entries owned by the app.

Because no data is sent to the developer, there is no server-side copy to delete.

## Children

Shellbee is a general-purpose home automation utility and is not directed at children. The app does not knowingly collect information from anyone, including children.

## Security

Authentication tokens are stored in the iOS Keychain. When connecting to a remote bridge, prefer `wss://` (TLS) so that traffic between your device and your bridge is encrypted. Connections over plain `ws://` are intended for trusted local networks.

## Changes to this policy

If this policy changes, the updated version will be published in the app's GitHub repository with a new "Last updated" date.

## Contact

For privacy questions about Shellbee, contact:

**tashda@gmail.com**
